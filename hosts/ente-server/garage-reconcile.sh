# shellcheck shell=bash

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

# READINESS

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

# LAYOUT

available_bytes="$(df --output=size -B1 "$DATA_DIR" | tail -1)"
desired=$((available_bytes * 90 / 100))

layout="$(admin GET /v1/layout)"

current="$(jq -r --arg id "$node_id" '[.roles[] | select(.id == $id) | .capacity] | first // 0' <<<"$layout")"

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

# S3 KEY

if [[ -s "$ACCESS_KEY_FILE" && -s "$SECRET_KEY_FILE" ]]; then
  access_key="$(<"$ACCESS_KEY_FILE")"
  secret_key="$(<"$SECRET_KEY_FILE")"
elif [[ ! -s "$ACCESS_KEY_FILE" && ! -s "$SECRET_KEY_FILE" ]]; then
  key_list="$(admin GET /v1/key)"

  if jq -e --arg n "$KEY_NAME" 'any(.[]; .name == $n)' <<<"$key_list" >/dev/null; then
    echo "Garage key $KEY_NAME exists but its credentials are missing." >&2
    echo "Garage never reveals a secret key twice; restore from backup." >&2
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

# BUCKET
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

# CORS

AWS_ACCESS_KEY_ID="$access_key" \
AWS_SECRET_ACCESS_KEY="$secret_key" \
  aws --endpoint-url "$S3_URL" s3api put-bucket-cors \
  --bucket "$BUCKET" \
  --cors-configuration "file://$CORS_POLICY"

echo "reconciliation complete"
