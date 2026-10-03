# shellcheck shell=bash
#
# Converge the NemoClaw Hermes sandbox on the generated manifest. Runs on every
# boot and every switch; each step is a no-op when already applied.
#
# Order differs from "providers first": `credentials add` needs a running
# gateway, and onboarding is what starts it. Providers registered after
# onboarding are attached at runtime, or by one rebuild if that fails.
#
# Environment:
#   NEMOCLAW_HERMES_MANIFEST  JSON {sandboxName, gpu, route, policyFile,
#                             extraPresets[], excludeBaseline[], settings[],
#                             providers[]}
#   <credentialEnv>           one per provider, from the agenix EnvironmentFiles

set -euo pipefail

manifest="$NEMOCLAW_HERMES_MANIFEST"
sandbox="$(jq -r '.sandboxName' "$manifest")"
state="$HOME/.nemoclaw-hermes"
install -d -m 0700 "$state"

# The gateway is a systemd user unit; reach this user's manager.
uid="$(id -u)"
export XDG_RUNTIME_DIR="/run/user/$uid"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
for _ in $(seq 60); do
  [[ -S "$XDG_RUNTIME_DIR/bus" ]] && break
  sleep 1
done
[[ -S "$XDG_RUNTIME_DIR/bus" ]] || {
  echo "user manager for uid $uid is not running (linger?)" >&2
  exit 1
}

hash() { sha256sum | cut -d' ' -f1; }

# Digests of what was last applied, one file per step.
changed() { [[ "$(cat "$state/$1" 2>/dev/null)" != "$2" ]]; }
record() { printf '%s' "$2" >"$state/$1"; }

sandbox_exists() {
  nemohermes list --json | jq -e --arg s "$sandbox" 'any(.sandboxes[]; .name == $s)' >/dev/null
}

attached_providers() {
  openshell sandbox provider list "$sandbox" | sed 's/\x1b\[[0-9;]*m//g' | awk 'NR > 1 { print $1 }'
}

# ONBOARD
fresh=0
if ! sandbox_exists; then
  echo "onboarding sandbox $sandbox"
  gpu_flag="--no-gpu"
  [[ "$(jq -r '.gpu' "$manifest")" == "true" ]] && gpu_flag="--gpu"
  nemohermes onboard --non-interactive --yes --yes-i-accept-third-party-software \
    --agent hermes --name "$sandbox" "$gpu_flag"
  fresh=1
fi

# Sandbox containers have no restart policy, so a host reboot leaves them
# stopped. `start` also repairs the in-sandbox gateway and host forwards.
if ((!fresh)); then
  nemohermes "$sandbox" start || nemohermes "$sandbox" recover
fi

route_digest="$(jq -c '.route' "$manifest" | hash)"

# Onboarding set the route; a recreated sandbox has lost policy and config.
if ((fresh)); then
  record route "$route_digest"
  rm -f "$state/policy" "$state/presets" "$state/exclusions" "$state/settings"
fi

# PROVIDERS
needs_rebuild=0
while IFS= read -r provider; do
  [[ -n "$provider" ]] || continue
  name="$(jq -r '.name' <<<"$provider")"
  type="$(jq -r '.type' <<<"$provider")"
  env="$(jq -r '.credentialEnv' <<<"$provider")"
  profile="$(jq -r '.profileFile' <<<"$provider")"

  [[ -n "${!env:-}" ]] || {
    echo "$name: $env is not set; check its agenix secret" >&2
    exit 1
  }

  # Profile: import once; on change, update against the live resource_version.
  profile_digest="$(hash <"$profile")"
  if ! current="$(openshell provider profile export "$type" -o json 2>/dev/null)"; then
    echo "$type: importing provider profile"
    openshell provider profile lint -f "$profile"
    openshell provider profile import -f "$profile"
    record "profile-$type" "$profile_digest"
  elif changed "profile-$type" "$profile_digest"; then
    echo "$type: updating provider profile"
    updated="$state/profile-$type.json"
    jq --argjson rv "$(jq '.resource_version' <<<"$current")" '. + {resource_version: $rv}' \
      "$profile" >"$updated"
    openshell provider profile lint -f "$updated"
    openshell provider profile update "$type" -f "$updated"
    record "profile-$type" "$profile_digest"
  fi

  # Credential: register once; rotate when the key changes.
  key_digest="$(printf '%s' "${!env}" | hash)"
  if ! openshell provider get "$type" >/dev/null 2>&1; then
    echo "$type: registering credential"
    nemohermes credentials add "$type" --type "$type" --credential "$env"
    record "key-$type" "$key_digest"
  elif changed "key-$type" "$key_digest"; then
    echo "$type: rotating credential"
    openshell provider update "$type" --credential "$env"
    record "key-$type" "$key_digest"
  fi

  # Attachment: runtime attach (providers v2), else rebuild once below.
  if ! attached_providers | grep -qx "$type"; then
    echo "$type: attaching to $sandbox"
    openshell sandbox provider attach "$sandbox" "$type" || needs_rebuild=1
  fi
done < <(jq -c '.providers[]' "$manifest")

if ((needs_rebuild)); then
  echo "rebuilding $sandbox to attach providers"
  nemohermes "$sandbox" rebuild --yes
  rm -f "$state/policy" "$state/presets" "$state/exclusions" "$state/settings"
fi

# ROUTE
if changed route "$route_digest"; then
  echo "switching inference route"
  nemohermes inference set --sandbox "$sandbox" \
    --provider "$(jq -r '.route.provider' "$manifest")" \
    --model "$(jq -r '.route.model' "$manifest")"
  record route "$route_digest"
fi

# POLICY
policy="$(jq -r '.policyFile' "$manifest")"
policy_digest="$(hash <"$policy")"
if changed policy "$policy_digest"; then
  echo "applying egress preset"
  nemohermes "$sandbox" policy add --from-file "$policy" --yes
  record policy "$policy_digest"
fi

presets_digest="$(jq -c '.extraPresets' "$manifest" | hash)"
if changed presets "$presets_digest"; then
  while IFS= read -r preset; do
    [[ -n "$preset" ]] || continue
    echo "adding preset $preset"
    nemohermes "$sandbox" policy add "$preset" --yes
  done < <(jq -r '.extraPresets[]' "$manifest")
  record presets "$presets_digest"
fi

# BASELINE EXCLUSIONS
exclusions_digest="$(jq -c '.excludeBaseline' "$manifest" | hash)"
if changed exclusions "$exclusions_digest"; then
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    # Already gone (an earlier partial run) is the goal state, not an error.
    if nemohermes "$sandbox" policy get | grep -q "^ *$key:"; then
      echo "excluding baseline entry $key"
      nemohermes "$sandbox" policy exclude "$key" --force --yes
    fi
  done < <(jq -r '.excludeBaseline[]' "$manifest")
  record exclusions "$exclusions_digest"
fi

# SETTINGS
settings_digest="$(jq -c '.settings' "$manifest" | hash)"
if changed settings "$settings_digest"; then
  echo "applying Hermes settings"
  while IFS= read -r setting; do
    [[ -n "$setting" ]] || continue
    nemohermes "$sandbox" config set --config-accept-new-path \
      --key "$(jq -r '.key' <<<"$setting")" \
      --value "$(jq -r '.value' <<<"$setting")"
  done < <(jq -c '.settings[]' "$manifest")
  nemohermes "$sandbox" gateway restart --quiet
  record settings "$settings_digest"
fi
