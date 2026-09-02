# shellcheck shell=bash
#
# Reconcile the Garage layout, S3 key and bucket that Ente needs.
#
# Driven entirely by Garage's admin API rather than by scraping the CLI's
# human-readable output: every value below is read out of JSON with jq, so a
# cosmetic change to `garage status` can no longer silently break provisioning.
#
# Idempotent throughout — a re-run on an unchanged box makes no writes.
#
# Environment:
#   ADMIN_URL          base URL of the Garage admin API
#   S3_URL             base URL of the Garage S3 API
#   DATA_DIR           Garage data directory, sized to pick the node capacity
#   BUCKET             global bucket alias to serve Ente from
#   KEY_NAME           name of the S3 key Ente authenticates with
#   ACCESS_KEY_FILE    where the S3 access key id is persisted
#   SECRET_KEY_FILE    where the S3 secret access key is persisted
#   CORS_POLICY        JSON file holding the bucket's CORS configuration
#   CREDENTIALS_DIRECTORY  systemd credential dir, holding `admin_token`

set -euo pipefail
umask 0077

admin() {
  local method="$1" path="$2"
  shift 2
  curl -fsS -X "$method" \
    -H "Authorization: Bearer $(<"$CREDENTIALS_DIRECTORY/admin_token")" \
    -H 'Content-Type: application/json' \
    "$@" "$ADMIN_URL$path"
}

# ---------------------------------------------------------------------------
# Readiness. The admin API is both the readiness signal and the interface
# everything below uses, so there is only one thing to wait on.
# ---------------------------------------------------------------------------

for _ in $(seq 60); do
  if admin GET /v1/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! admin GET /v1/health >/dev/null 2>&1; then
  echo "Garage admin API never became ready" >&2
  exit 1
fi

node_id="$(admin GET /v1/status | jq -er '.node')"
echo "node: $node_id"

# ---------------------------------------------------------------------------
# Layout: give this node ~90% of the filesystem. The staged change is only
# submitted when the assigned capacity actually differs, so re-running on an
# unchanged box is a no-op rather than a pointless new layout version.
# ---------------------------------------------------------------------------

available_bytes="$(df --output=size -B1 "$DATA_DIR" | tail -1)"
desired=$((available_bytes * 90 / 100))

layout="$(admin GET /v1/layout)"

current="$(jq -r --arg id "$node_id" '[.roles[] | select(.id == $id) | .capacity] | first // 0' <<<"$layout")"

# Re-sent as-is on every restage below: this node's role is fully replaced
# by the POST, so a hardcoded `tags: []` here would silently wipe out any
# tags an operator set by hand (e.g. via `garage layout assign -t`) the next
# time disk size drifts and this block re-runs.
tags="$(jq -c --arg id "$node_id" '[.roles[] | select(.id == $id) | .tags] | first // []' <<<"$layout")"

if [[ "$current" != "$desired" ]]; then
  echo "staging capacity $current -> $desired"

  admin POST /v1/layout --data "$(jq -n \
    --arg id "$node_id" \
    --argjson capacity "$desired" \
    --argjson tags "$tags" \
    '[{id: $id, zone: "dc1", capacity: $capacity, tags: $tags}]')" >/dev/null

  version="$(admin GET /v1/layout | jq -er '.version')"

  admin POST /v1/layout/apply --data "$(jq -n \
    --argjson version "$((version + 1))" '{version: $version}')" >/dev/null
fi

# ---------------------------------------------------------------------------
# S3 key.
#
#   both credential files present -> reuse them
#   neither present               -> mint a key and persist both
#   key exists but files do not   -> fail. Garage never reveals a secret key
#                                    twice, so the only route back is a restore
#   exactly one present           -> fail. A half-written pair means something
#                                    went wrong on an earlier run
# ---------------------------------------------------------------------------

if [[ -s "$ACCESS_KEY_FILE" && -s "$SECRET_KEY_FILE" ]]; then
  access_key="$(<"$ACCESS_KEY_FILE")"
  secret_key="$(<"$SECRET_KEY_FILE")"
elif [[ ! -s "$ACCESS_KEY_FILE" && ! -s "$SECRET_KEY_FILE" ]]; then
  # Fetched separately from the existence check below: under `set -e`, a
  # failed `admin GET` inside the `if` here would just make the condition
  # false — indistinguishable from "the key genuinely doesn't exist" — and
  # fall through to minting a second key under the same name. Garage never
  # re-reveals a secret key, so that would silently orphan a real one. This
  # way a transient API failure fails the script loudly instead.
  key_list="$(admin GET /v1/key)"

  if jq -e --arg n "$KEY_NAME" 'any(.[]; .name == $n)' <<<"$key_list" >/dev/null; then
    echo "Garage key $KEY_NAME exists but its credentials are missing." >&2
    echo "Garage never reveals a secret key twice — restore from backup." >&2
    exit 1
  fi

  echo "creating key $KEY_NAME"
  key_info="$(admin POST /v1/key --data "$(jq -n --arg name "$KEY_NAME" '{name: $name}')")"
  access_key="$(jq -er '.accessKeyId' <<<"$key_info")"
  secret_key="$(jq -er '.secretAccessKey' <<<"$key_info")"

  printf '%s' "$access_key" >"$ACCESS_KEY_FILE"
  printf '%s' "$secret_key" >"$SECRET_KEY_FILE"
  chmod 0400 "$ACCESS_KEY_FILE" "$SECRET_KEY_FILE"
else
  echo "incomplete Garage credentials: exactly one of the pair exists" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Bucket and grant. CreateBucket rejects an alias that already exists, so the
# lookup comes first; the grant itself is idempotent.
# ---------------------------------------------------------------------------

# The `|| true` is load-bearing, not decorative: a not-yet-created alias
# makes `admin` (curl -f) exit non-zero, and under `set -euo pipefail` that
# would otherwise abort the whole script right here on every fresh deploy —
# the one time this bucket genuinely doesn't exist and the rest of this
# script's job is to create it. `2>/dev/null` alone only silences curl's
# stderr text; it does nothing to the exit code.
bucket_id="$(admin GET "/v1/bucket?globalAlias=$BUCKET" 2>/dev/null | jq -r '.id // empty' || true)"

if [[ -z "$bucket_id" ]]; then
  echo "creating bucket $BUCKET"
  bucket_id="$(admin POST /v1/bucket \
    --data "$(jq -n --arg alias "$BUCKET" '{globalAlias: $alias}')" | jq -er '.id')"
fi

admin POST /v1/bucket/allow --data "$(jq -n \
  --arg bucket "$bucket_id" \
  --arg key "$access_key" \
  '{bucketId: $bucket, accessKeyId: $key,
    permissions: {read: true, write: true, owner: true}}')" >/dev/null

# ---------------------------------------------------------------------------
# CORS is genuinely an S3 operation rather than an admin one — the v1 admin API
# has no CORS endpoint — so this is the single place an S3 client is needed.
# ---------------------------------------------------------------------------

AWS_ACCESS_KEY_ID="$access_key" \
AWS_SECRET_ACCESS_KEY="$secret_key" \
  aws --endpoint-url "$S3_URL" s3api put-bucket-cors \
  --bucket "$BUCKET" \
  --cors-configuration "file://$CORS_POLICY"

echo "reconciliation complete"
