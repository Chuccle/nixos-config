#!/usr/bin/env bash
set -euo pipefail

adapter=${1:?pass the window-action script path}
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
export MOCK_ROOT=$root XDG_RUNTIME_DIR="$root/runtime"
mkdir -p "$root/bin" "$XDG_RUNTIME_DIR"
export PATH="$root/bin:$PATH"

if [[ $(uname -s) == MINGW* ]]; then
    jq_binary=$(command -v jq)
    cat >"$root/bin/jq" <<MOCK_JQ
#!/usr/bin/env bash
set -o pipefail
"$jq_binary" "\$@" | tr -d '\r'
MOCK_JQ
    chmod +x "$root/bin/jq"
fi

# Git Bash has no flock; the production Nix check uses util-linux's flock.
if ! command -v flock >/dev/null; then
    printf '#!/usr/bin/env bash\nexit 0\n' >"$root/bin/flock"
    chmod +x "$root/bin/flock"
fi

printf '#!%s\n' "$(command -v bash)" >"$root/bin/niri"
cat >>"$root/bin/niri" <<'MOCK'
set -euo pipefail
if [[ $1 == msg && $2 == --json ]]; then
    cat "$MOCK_ROOT/$3.json"
    exit
fi
[[ $1 == msg && $2 == action ]] || exit 1
shift 2
printf '%s\n' "$*" >>"$MOCK_ROOT/actions"
case $1 in
    move-window-to-workspace)
        shift
        id= target=
        while (($#)); do
            case $1 in
                --window-id) id=$2; shift 2 ;;
                --focus=*) shift ;;
                *) target=$1; shift ;;
            esac
        done
        [[ ${MOCK_FAIL_MOVE:-0} != 1 ]] || exit 1
        workspace=$(jq -r --arg name "$target" '[.[] | select(.name == $name) | .id][0]' "$MOCK_ROOT/workspaces.json")
        jq --argjson id "$id" --argjson workspace "$workspace" \
            'map(if .id == $id then .workspace_id = $workspace | .is_focused = false else . end)' \
            "$MOCK_ROOT/windows.json" >"$MOCK_ROOT/windows.tmp"
        mv "$MOCK_ROOT/windows.tmp" "$MOCK_ROOT/windows.json"
        ;;
    focus-window)
        id=$3
        jq --argjson id "$id" 'map(.is_focused = (.id == $id))' \
            "$MOCK_ROOT/windows.json" >"$MOCK_ROOT/windows.tmp"
        mv "$MOCK_ROOT/windows.tmp" "$MOCK_ROOT/windows.json"
        ;;
    close-window)
        id=$3
        jq --argjson id "$id" 'map(select(.id != $id))' \
            "$MOCK_ROOT/windows.json" >"$MOCK_ROOT/windows.tmp"
        mv "$MOCK_ROOT/windows.tmp" "$MOCK_ROOT/windows.json"
        ;;
esac
MOCK
chmod +x "$root/bin/niri"

cat >"$root/workspaces.json" <<'JSON'
[{"id":1,"name":"desktop","idx":1,"is_active":true},{"id":2,"name":"parked","idx":2,"is_active":false}]
JSON
cat >"$root/windows.json" <<'JSON'
[
  {"id":10,"workspace_id":1,"is_floating":true,"is_focused":true,"layout":{"window_size":[640,480],"tile_pos_in_workspace_view":[50,70],"window_offset_in_tile":[1,1]}},
  {"id":11,"workspace_id":1,"is_floating":true,"is_focused":false,"layout":{"window_size":[800,600],"tile_pos_in_workspace_view":[100,120],"window_offset_in_tile":[1,1]}}
]
JSON

record="$XDG_RUNTIME_DIR/win95-window-state/10.json"
bash "$adapter" hide 10 >/dev/null
[[ -f $record ]]
jq -e '.workspace_id == 1 and .layout.window_size == [640,480]' "$record" >/dev/null
jq -e 'any(.[]; .id == 10 and .workspace_id == 2)' "$root/windows.json" >/dev/null
cp "$record" "$root/saved-record.json"
bash "$adapter" state | jq -e '.parked == [10]' >/dev/null

bash "$adapter" restore 10 >/dev/null
[[ ! -e $record ]]
jq -e 'any(.[]; .id == 10 and .workspace_id == 1 and .is_focused)' "$root/windows.json" >/dev/null
grep -Fx 'set-window-width --id 10 640' "$root/actions" >/dev/null
grep -Fx 'set-window-height --id 10 480' "$root/actions" >/dev/null
grep -Fx 'move-floating-window --id 10 -x 51 -y 71' "$root/actions" >/dev/null

# Interrupted hide or restore operations must reconcile with live windows.
cp "$root/saved-record.json" "$record"
bash "$adapter" state | jq -e '.parked == []' >/dev/null
[[ ! -e $record ]]
printf '{"id":99,"show_desktop":false}\n' >"$XDG_RUNTIME_DIR/win95-window-state/99.json"
bash "$adapter" state | jq -e '.parked == []' >/dev/null
[[ ! -e "$XDG_RUNTIME_DIR/win95-window-state/99.json" ]]

bash "$adapter" show-desktop | jq -e '.parked == [10,11]' >/dev/null
bash "$adapter" show-desktop | jq -e '.parked == []' >/dev/null
jq -e 'all(.[]; .workspace_id == 1)' "$root/windows.json" >/dev/null
jq -e 'any(.[]; .id == 10 and .is_focused)' "$root/windows.json" >/dev/null

bash "$adapter" hide 10 >/dev/null
cat >"$root/workspaces.json" <<'JSON'
[{"id":3,"name":"desktop","idx":1,"is_active":true},{"id":2,"name":"parked","idx":2,"is_active":false}]
JSON
bash "$adapter" restore 10 >/dev/null
jq -e 'any(.[]; .id == 10 and .workspace_id == 3)' "$root/windows.json" >/dev/null

if MOCK_FAIL_MOVE=1 bash "$adapter" hide 11 >/dev/null 2>&1; then
    echo 'A failed hide command was accepted' >&2
    exit 1
fi
[[ ! -e "$XDG_RUNTIME_DIR/win95-window-state/11.json" ]]
echo 'Win95 window-action tests passed.'
