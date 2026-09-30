# Niri owns the event stream and window commands. This adapter stores restore targets.
set -euo pipefail
state="${XDG_RUNTIME_DIR:?}/win95-window-state"
mkdir -p "$state"
chmod 700 "$state"
exec 9>"$state/lock"
flock 9
windows=$(niri msg --json windows)
workspaces=$(niri msg --json workspaces)
parked_id=$(jq -r '[.[] | select(.name == "parked") | .id][0] // empty' <<<"$workspaces")
[[ -n "$parked_id" ]] || { echo 'Parking workspace missing' >&2; exit 1; }
for record in "$state"/*.json; do
    [[ -e "$record" ]] || continue
    id="$(basename "$record" .json)"
    if ! jq -e --argjson id "$id" --argjson parked "$parked_id" 'any(.[]; .id == $id and .workspace_id == $parked)' <<<"$windows" >/dev/null; then rm "$record"; fi
done
snapshot() {
    local records=()
    for record in "$state"/*.json; do [[ ! -e "$record" ]] || records+=("$record"); done
    if ((${#records[@]})); then jq -cs '{parked:map(.id)}' "${records[@]}"; else printf '{"parked":[]}\n'; fi
}
hide() {
    local id=$1 desktop=${2:-false}
    [[ ! -f "$state/$id.json" ]] || return 0
    jq -e --argjson id "$id" --argjson desktop "$desktop" '.[] | select(.id==$id) | {id,workspace_id,is_floating,is_focused,layout,show_desktop:$desktop}' <<<"$windows" >"$state/$id.tmp"
    mv "$state/$id.tmp" "$state/$id.json"
    if ! niri msg action move-window-to-workspace --window-id "$id" --focus=false parked >/dev/null; then
        rm "$state/$id.json"
        return 1
    fi
}
restore() {
    local id=$1 target workspace_id x y width height
    if [[ -f "$state/$id.json" ]]; then
        workspace_id=$(jq -r '.workspace_id' "$state/$id.json")
        target=$(jq -r --argjson id "$workspace_id" '.[] | select(.id==$id) | .name // (.idx|tostring)' <<<"$workspaces")
        target=${target:-desktop}
        niri msg action move-window-to-workspace --window-id "$id" --focus=false "$target" >/dev/null
        read -r width height < <(jq -r '.layout.window_size | @tsv' "$state/$id.json")
        read -r x y < <(jq -r '[(.layout.tile_pos_in_workspace_view[0] // 0)+(.layout.window_offset_in_tile[0] // 0),(.layout.tile_pos_in_workspace_view[1] // 0)+(.layout.window_offset_in_tile[1] // 0)] | @tsv' "$state/$id.json")
        niri msg action set-window-width --id "$id" "$width" >/dev/null
        niri msg action set-window-height --id "$id" "$height" >/dev/null
        if jq -e '.is_floating' "$state/$id.json" >/dev/null; then
            niri msg action move-window-to-floating --id "$id" >/dev/null
            niri msg action move-floating-window --id "$id" -x "$x" -y "$y" >/dev/null
        fi
        rm "$state/$id.json"
    fi
    niri msg action focus-window --id "$id" >/dev/null
}
action=${1:-state}
id=${2:-$(jq -r '.[] | select(.is_focused) | .id' <<<"$windows")}
if [[ "$action" == show-desktop ]]; then
    desktop_records=()
    for record in "$state"/*.json; do
        if [[ -e "$record" ]] && jq -e '.show_desktop' "$record" >/dev/null; then desktop_records+=("$record"); fi
    done
    if ((${#desktop_records[@]})); then
        focused=""
        for record in "${desktop_records[@]}"; do
            window_id=$(jq -r '.id' "$record")
            if jq -e '.is_focused' "$record" >/dev/null; then focused=$window_id; fi
            restore "$window_id"
        done
        [[ -z "$focused" ]] || niri msg action focus-window --id "$focused" >/dev/null
    else
        active=$(jq -c '[.[] | select(.is_active) | .id]' <<<"$workspaces")
        while read -r window_id; do hide "$window_id" true; done < <(jq -r --argjson active "$active" '.[] | select(.workspace_id as $id | $active | index($id)) | .id' <<<"$windows")
    fi
elif [[ "$action" != state ]]; then
    [[ "$id" =~ ^[0-9]+$ ]] || { echo 'No selected window' >&2; exit 1; }
    case "$action" in
        hide) hide "$id" ;;
        restore|activate) restore "$id" ;;
        toggle) if [[ -f "$state/$id.json" ]]; then restore "$id"; elif jq -e --argjson id "$id" '.[] | select(.id==$id) | .is_focused' <<<"$windows" >/dev/null; then hide "$id"; else restore "$id"; fi ;;
        close) niri msg action close-window --id "$id" >/dev/null ;;
        maximize) restore "$id"; niri msg action maximize-window-to-edges >/dev/null ;;
        *) echo 'Unknown window action' >&2; exit 1 ;;
    esac
fi
snapshot
