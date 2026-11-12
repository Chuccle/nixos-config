# shellcheck shell=bash

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

    tmp="$(mktemp "$(dirname "$path")/.provisioning.XXXXXX")"
    # shellcheck disable=SC2064
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
