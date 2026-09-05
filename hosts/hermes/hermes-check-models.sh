# shellcheck shell=bash
#
# Weekly drift check for the free-tier ladder, run by systemd
# (hermes-check-models.timer) — never by either agent. Same reasoning as
# ZeroClaw's equivalent: the risk engine has no notion of this script's own
# read-only intent, so a standalone unit outside the agents' tool-call path
# is what keeps this uninvokable rather than merely unlisted.
#
# Deliberately not LiteLLM's own `background_health_checks`: that option
# runs a real completion against every deployment, spending the very quota
# this ladder exists to protect. Every vendor here publishes a keyless-cost
# `/models` catalog listing instead — confirmed live that it responds 200
# even on the Cerebras key currently blocked on billing for completions —
# so this checks the same drift (a renamed or retired model id) without
# spending a token.
#
# The vendor list is read from a generated JSON file rather than baked in,
# so adding a rung to the ladder needs no change here: each entry carries
# its own catalog URL, auth style, and the jq filter that extracts bare
# ids from that vendor's response shape (Gemini's differs from the other
# three, which is why this is data and not one hardcoded jq expression).
#
# Environment:
#   CATALOG_SPEC   path to the generated vendor/model JSON
#   (vendor keys arrive already injected — the unit's own EnvironmentFile
#   points at LiteLLM's credential file, loaded by systemd before this ever
#   runs, not read here: the file is 0400 root:root and this runs as an
#   unprivileged DynamicUser)

set -uo pipefail

overall_status=0
vendor_count=0
ok_count=0
warn_count=0

echo "🩺 Hermes — Free-Tier Ladder Catalog Check"
echo

while IFS= read -r entry; do
  vendor_count=$((vendor_count + 1))

  vendor="$(jq -r '.vendor' <<<"$entry")"
  url="$(jq -r '.url' <<<"$entry")"
  auth_mode="$(jq -r '.authMode' <<<"$entry")"
  key_env="$(jq -r '.keyEnv' <<<"$entry")"
  id_path="$(jq -r '.idPath' <<<"$entry")"
  key="${!key_env:-}"

  echo "  [$vendor]"

  if [[ -z "$key" ]]; then
    echo "    ⚠️  $key_env not set — skipped"
    overall_status=1
    continue
  fi

  if [[ "$auth_mode" == bearer ]]; then
    response="$(curl -s -w '\n%{http_code}' "$url" -H "Authorization: Bearer $key")"
  else
    sep='?'
    [[ "$url" == *'?'* ]] && sep='&'
    response="$(curl -s -w '\n%{http_code}' "${url}${sep}key=${key}")"
  fi

  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  if [[ "$status" != "200" ]]; then
    echo "    ⚠️  catalog fetch failed (HTTP $status)"
    overall_status=1
    continue
  fi

  live_ids="$(jq -r "$id_path" <<<"$body" 2>/dev/null)"

  while IFS= read -r model; do
    [[ -n "$model" ]] || continue

    if grep -qxF "$model" <<<"$live_ids"; then
      echo "    ✅ $model"
      ok_count=$((ok_count + 1))
    else
      echo "    ⚠️  $model — not in live catalog"
      warn_count=$((warn_count + 1))
      overall_status=1
    fi
  done < <(jq -r '.models[]' <<<"$entry")
done < <(jq -c '.[]' "$CATALOG_SPEC")

echo
echo "Summary: $ok_count ok, $warn_count warning(s), across $vendor_count vendor(s)"

exit "$overall_status"
