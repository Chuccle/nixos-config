# shellcheck shell=bash

set -euo pipefail
umask 0077

# READINESS

status=""
last_error=""
for _ in $(seq 60); do
  if status="$(garage json-api GetClusterStatus 2>&1)"; then
    break
  fi
  last_error="$status"
  status=""
  sleep 2
done

if [[ -z "$status" ]]; then
  echo "Garage never became ready: ${last_error:-no output}" >&2
  exit 1
fi

node_id="$(jq -r --arg addr "$RPC_ADDR" '.nodes[] | select(.addr == $addr) | .id' <<<"$status" | head -1)"

if [[ -z "$node_id" ]]; then
  echo "could not identify this node by rpc address $RPC_ADDR" >&2
  exit 1
fi

echo "node: $node_id"

# LAYOUT

available_bytes="$(df --output=size -B1 "$DATA_DIR" | tail -1)"
desired=$((available_bytes * 90 / 100))

layout="$(garage json-api GetClusterLayout)"
version="$(jq -er '.version' <<<"$layout")"
current="$(jq -r --arg id "$node_id" '[.roles[] | select(.id == $id) | .capacity] | first // 0' <<<"$layout")"

if [[ "$current" != "$desired" ]]; then
  echo "staging capacity $current -> $desired"

  tags=()
  while IFS= read -r tag; do
    [[ -n "$tag" ]] && tags+=(-t "$tag")
  done < <(jq -r --arg id "$node_id" '[.roles[] | select(.id == $id) | .tags[]] | .[]' <<<"$layout")

  garage layout assign -z dc1 -c "$desired" "${tags[@]}" "$node_id" >/dev/null
  garage layout apply --version "$((version + 1))" >/dev/null
fi

# S3 KEY

if [[ -s "$ACCESS_KEY_FILE" && -s "$SECRET_KEY_FILE" ]]; then
  access_key="$(<"$ACCESS_KEY_FILE")"
  secret_key="$(<"$SECRET_KEY_FILE")"
elif [[ ! -s "$ACCESS_KEY_FILE" && ! -s "$SECRET_KEY_FILE" ]]; then
  key_list="$(garage json-api ListKeys)"

  if jq -e --arg n "$KEY_NAME" 'any(.[]; .name == $n)' <<<"$key_list" >/dev/null; then
    echo "Garage key $KEY_NAME exists but its credentials are missing." >&2
    echo "Garage never reveals a secret key twice; restore from backup." >&2
    exit 1
  fi

  echo "creating key $KEY_NAME"

  key_info="$(garage json-api CreateKey "$(jq -n --arg name "$KEY_NAME" '{name: $name}')")"
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

bucket_id="$(
  garage json-api ListBuckets |
    jq -r --arg b "$BUCKET" '[.[] | select(.globalAliases | index($b)) | .id] | first // empty'
)"

if [[ -z "$bucket_id" ]]; then
  echo "creating bucket $BUCKET"
  bucket_id="$(garage json-api CreateBucket "$(jq -n --arg alias "$BUCKET" '{globalAlias: $alias}')" | jq -er '.id')"
fi

garage json-api AllowBucketKey "$(jq -n \
  --arg bucket "$bucket_id" \
  --arg key "$access_key" \
  '{bucketId: $bucket, accessKeyId: $key, permissions: {read: true, write: true, owner: true}}')" >/dev/null

# CORS

AWS_ACCESS_KEY_ID="$access_key" \
AWS_SECRET_ACCESS_KEY="$secret_key" \
  aws --endpoint-url "$S3_URL" s3api put-bucket-cors \
  --bucket "$BUCKET" \
  --cors-configuration "file://$CORS_POLICY"

echo "reconciliation complete"
