# shellcheck shell=bash
#
# Provision the vendor API keys the free-tier ladder rotates through.
#
# Interactive and operator-run — never invoked at boot, so an unattended
# reboot can never wedge at a prompt. Rotating a key is re-running this rather
# than deleting a file and rebooting.
#
# The ladder is read from a generated JSON file rather than baked in, so
# adding a vendor to the Nix configuration needs no change here.
#
# Environment:
#   PROVIDERS   JSON array of {family, envVar}, best-first
#   ENV_FILE    where the resulting EnvironmentFile is written
#   UNIT        systemd unit to restart once the file is in place

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "zeroclaw-keys must run as root" >&2
  exit 1
fi

umask 0077
install -d -m 0700 -o root -g root "$(dirname "$ENV_FILE")"

tmp="$(mktemp "$(dirname "$ENV_FILE")/.providers.XXXXXX")"
# shellcheck disable=SC2064  # $tmp is intentionally expanded now, not at trap time
trap "rm -f '$tmp'" EXIT

echo "Leave a vendor blank to skip it — the ladder just falls through to the next."

# Read into an array first rather than piping straight into the loop's
# stdin: `while read ... done < <(...)` redirects the *whole loop's* stdin,
# so the interactive `read -rsp` below would consume from that same stream
# instead of the terminal — silently eating the next vendor's own line
# rather than ever pausing for a keystroke.
mapfile -t provider_lines < <(jq -r '.[] | [.family, .envVar] | @tsv' "$PROVIDERS")

for line in "${provider_lines[@]}"; do
  IFS=$'\t' read -r family env_var <<<"$line"
  [[ -n "$family" ]] || continue

  read -rsp "$family API key: " key
  echo

  if [[ -n "$key" ]]; then
    printf '%s=%s\n' "$env_var" "$key" >>"$tmp"
  fi
done

if [[ ! -s "$tmp" ]]; then
  echo "No keys entered — leaving $ENV_FILE untouched." >&2
  exit 1
fi

chmod 0400 "$tmp"
mv -f "$tmp" "$ENV_FILE"
trap - EXIT

echo "Wrote $ENV_FILE. Restarting $UNIT."
systemctl restart "$UNIT"
