# shellcheck shell=bash
#
# Reconcile the persistent secret store from a generated manifest.
#
# The manifest is JSON rather than generated shell: adding a secret changes
# data, never this control flow. Every declared secret is idempotent — a
# generator only runs when the file is missing or empty, and permissions are
# reconciled on every pass whether or not the content was touched.
#
# Environment:
#   SECRETS_MANIFEST  JSON array of {name, path, generator|null, owner, group, mode}

set -euo pipefail
umask 0077

entries="$(jq -c '.[]' "$SECRETS_MANIFEST")"

while IFS= read -r entry; do
  [[ -n "$entry" ]] || continue

  name="$(jq -r '.name' <<<"$entry")"
  path="$(jq -r '.path' <<<"$entry")"
  generator="$(jq -r '.generator // empty' <<<"$entry")"
  owner="$(jq -r '.owner' <<<"$entry")"
  group="$(jq -r '.group' <<<"$entry")"
  mode="$(jq -r '.mode' <<<"$entry")"

  install -d -m 0700 -o root -g root "$(dirname "$path")"

  if [[ -n "$generator" && ! -s "$path" ]]; then
    echo "provisioning $name"

    # Written beside the target and renamed into place, so a kill mid-write
    # can never leave a truncated credential that later looks provisioned.
    tmp="$(mktemp "$(dirname "$path")/.provisioning.XXXXXX")"
    # shellcheck disable=SC2064  # $tmp is intentionally expanded now, not at trap time
    trap "rm -f '$tmp'" EXIT

    if ! "$generator" >"$tmp"; then
      echo "$name: generator failed" >&2
      exit 1
    fi

    if [[ ! -s "$tmp" ]]; then
      echo "$name: generator produced nothing" >&2
      exit 1
    fi

    mv -f "$tmp" "$path"
    trap - EXIT
  fi

  if [[ -e "$path" ]]; then
    chmod "$mode" "$path"
    chown "$owner:$group" "$path"
  fi
done <<<"$entries"
