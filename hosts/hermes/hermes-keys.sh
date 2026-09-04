# shellcheck shell=bash
#
# Provision every credential the inference stack needs.
#
# Interactive and operator-run — never invoked at boot, so an unattended
# reboot can never wedge at a prompt. Rotating anything is re-running this
# rather than deleting files and rebooting.
#
# Two kinds of secret. The vendor API keys and the dashboard password have no
# local source of truth, so they are asked for; everything else is
# machine-generated here, because a shared bearer token that a human types
# twice is a shared bearer token that eventually differs between two files.
#
# One env file per unit, each holding only what that unit needs, so a
# compromise of either agent — both of which run arbitrary commands as their
# own user by design — does not hand over the vendor keys. systemd reads these
# as root before dropping privileges, so 0400 root:root works and no service
# user can open the file itself.
#
# The vendor list is read from a generated JSON file rather than baked in, so
# adding a rung to the Nix configuration needs no change here.
#
# Environment:
#   VENDOR_KEYS   JSON array of environment-variable names, one per vendor
#   SECRETS_DIR   directory the env files are written into
#   LITELLM_ENV   EnvironmentFile for the gateway
#   HERMES_ENV    EnvironmentFile for the Hermes dashboard
#   OPENCODE_ENV  EnvironmentFile for the opencode server
#   MEMORY_ENV    EnvironmentFile for the ai-memory server

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "hermes-keys must run as root" >&2
  exit 1
fi

umask 0077
install -d -m 0700 -o root -g root "$SECRETS_DIR"

work="$(mktemp -d "$SECRETS_DIR/.provisioning.XXXXXX")"
# shellcheck disable=SC2064  # $work is intentionally expanded now, not at trap time
trap "rm -rf '$work'" EXIT

# ---------------------------------------------------------------------------
# Vendor keys
# ---------------------------------------------------------------------------

echo "Leave a vendor blank to skip it — the ladder just falls through to the next rung."

# Read into an array first rather than piping straight into the loop's stdin:
# `while read ... done < <(...)` redirects the *whole loop's* stdin, so the
# interactive `read -rsp` below would consume from that same stream instead of
# the terminal — silently eating the next vendor's own line rather than ever
# pausing for a keystroke.
mapfile -t vendor_vars < <(jq -r '.[]' "$VENDOR_KEYS")

for env_var in "${vendor_vars[@]}"; do
  [[ -n "$env_var" ]] || continue

  read -rsp "$env_var: " key
  echo

  if [[ -n "$key" ]]; then
    printf '%s=%s\n' "$env_var" "$key" >>"$work/vendors"
  fi
done

if [[ ! -s "$work/vendors" ]]; then
  echo "No vendor keys entered — every rung of the ladder would fail. Nothing written." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Dashboard login
# ---------------------------------------------------------------------------
#
# Hermes refuses a non-loopback dashboard bind with no auth provider
# registered, so this is not optional on this host.

read -rp "Hermes dashboard username [admin]: " dashboard_user
dashboard_user="${dashboard_user:-admin}"

read -rsp "Hermes dashboard password: " dashboard_password
echo
read -rsp "Confirm: " dashboard_password_confirm
echo

if [[ -z "$dashboard_password" || "$dashboard_password" != "$dashboard_password_confirm" ]]; then
  echo "Passwords empty or did not match. Nothing written." >&2
  exit 1
fi

# Hermes stores this as scrypt$n$r$p$<salt_b64>$<dk_b64>, and its verifier
# reads n, r and p out of the string and takes the key length from the stored
# digest — so the parameters chosen here cannot drift out of compatibility.
# These are the interactive-login parameters upstream uses (~16 MiB).
#
# Computed here rather than by importing Hermes' own `hash_password`: that
# module pulls in `hermes_cli.dashboard_auth`, which needs the wrapper's
# interpreter and source root, neither of which a plain shell script has a
# supported way to reach.
#
# Handed over in the environment, not in argv. `/proc/<pid>/cmdline` is
# world-readable no matter who owns the process, so an argument would put the
# operator's plaintext password where any local user could read it for as long
# as the hash takes to compute — and on this host the local users include two
# agents that run arbitrary commands by design. `/proc/<pid>/environ` is
# readable only by the process owner, which here is root.
dashboard_hash="$(
  DASHBOARD_PASSWORD="$dashboard_password" python3 - <<'PY'
import base64
import hashlib
import os
import secrets

n, r, p, dklen = 2**14, 8, 1, 32
salt = secrets.token_bytes(16)
dk = hashlib.scrypt(
    os.environ["DASHBOARD_PASSWORD"].encode("utf-8"),
    salt=salt,
    n=n,
    r=r,
    p=p,
    dklen=dklen,
    maxmem=0,
)
print(
    f"scrypt${n}${r}${p}$"
    f"{base64.b64encode(salt).decode()}${base64.b64encode(dk).decode()}"
)
PY
)"

# ---------------------------------------------------------------------------
# Machine-generated shared secrets
# ---------------------------------------------------------------------------

gateway_key="sk-$(openssl rand -hex 32)"
memory_token="$(openssl rand -hex 32)"
opencode_password="$(openssl rand -hex 24)"
dashboard_secret="$(openssl rand -hex 32)"

# ---------------------------------------------------------------------------
# Per-unit env files
# ---------------------------------------------------------------------------

{
  cat "$work/vendors"
  printf 'LITELLM_MASTER_KEY=%s\n' "$gateway_key"
} >"$work/litellm"

{
  printf 'LITELLM_MASTER_KEY=%s\n' "$gateway_key"
  printf 'AI_MEMORY_AUTH_TOKEN=%s\n' "$memory_token"
  printf 'HERMES_DASHBOARD_BASIC_AUTH_USERNAME=%s\n' "$dashboard_user"
  printf 'HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH=%s\n' "$dashboard_hash"
  printf 'HERMES_DASHBOARD_BASIC_AUTH_SECRET=%s\n' "$dashboard_secret"
} >"$work/hermes"

{
  printf 'LITELLM_MASTER_KEY=%s\n' "$gateway_key"
  printf 'AI_MEMORY_AUTH_TOKEN=%s\n' "$memory_token"
  printf 'OPENCODE_SERVER_PASSWORD=%s\n' "$opencode_password"
} >"$work/opencode"

# ai-memory reads its own bearer from AI_MEMORY_AUTH_TOKEN and, for the
# `openai-compat` consolidation provider, its upstream credential from
# LLM_API_KEY.
{
  printf 'AI_MEMORY_AUTH_TOKEN=%s\n' "$memory_token"
  printf 'LLM_API_KEY=%s\n' "$gateway_key"
} >"$work/ai-memory"

install -m 0400 -o root -g root "$work/litellm" "$LITELLM_ENV"
install -m 0400 -o root -g root "$work/hermes" "$HERMES_ENV"
install -m 0400 -o root -g root "$work/opencode" "$OPENCODE_ENV"
install -m 0400 -o root -g root "$work/ai-memory" "$MEMORY_ENV"

rm -rf "$work"
trap - EXIT

echo
echo "Wrote credentials for $(wc -l <"$LITELLM_ENV") gateway variables and three clients."
echo "opencode web login:  opencode / $opencode_password"
echo "Hermes dashboard:    $dashboard_user / (the password you just set)"
echo

# Ordered so the agents reconnect to backends that are already up. Restarting
# rather than reloading: none of the four re-reads its EnvironmentFile without
# a restart.
systemctl restart litellm.service ai-memory.service
systemctl restart hermes-dashboard.service opencode.service
