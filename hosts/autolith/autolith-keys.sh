# shellcheck shell=bash
#
# Provision the free-tier API keys init.lisp reads at every autolith start.
#
# Interactive and operator-run — never invoked at boot, so an unattended
# reboot can never wedge at a prompt. Rotating a key is re-running this
# rather than deleting a file and rebooting.
#
# Gemini is deliberately not asked for here: it authenticates via a one-time
# interactive OAuth flow (`autolith auth gemini`), not an environment
# variable, so there is nothing this script could provision for it.
#
# Environment:
#   ENV_FILE   where the resulting EnvironmentFile is written
#   UNIT       systemd unit to restart once the file is in place

set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "autolith-keys must run as root" >&2
  exit 1
fi

umask 0077
install -d -m 0700 -o root -g root "$(dirname "$ENV_FILE")"

tmp="$(mktemp "$(dirname "$ENV_FILE")/.providers.XXXXXX")"
# shellcheck disable=SC2064  # $tmp is intentionally expanded now, not at trap time
trap "rm -f '$tmp'" EXIT

echo "Leave a vendor blank to skip it."
echo "(Gemini isn't asked for here — run 'autolith auth gemini' from an attached session instead.)"

for var in GROQ_API_KEY CEREBRAS_API_KEY OPENROUTER_API_KEY MISTRAL_API_KEY; do
  read -rsp "${var}: " key
  echo

  if [[ -n "$key" ]]; then
    printf '%s=%s\n' "$var" "$key" >>"$tmp"
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
