# Edge script discovery under scripts/edge/.

edge_script_path() {
  local name="$1" path="${EDGE_DIR}/${name}"
  [[ -f "$path" ]] && { echo "$path"; return 0; }
  return 1
}

list_edge_scripts() {
  local f name
  [[ -d "$EDGE_DIR" ]] || return 1
  for f in "$EDGE_DIR"/*; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f")"
    printf '  %s\n' "$name"
  done
}
