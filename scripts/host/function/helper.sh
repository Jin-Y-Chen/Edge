#!/usr/bin/env bash
# Shared helpers for host inject / reject / uninstall.

expand_path() {
  local path="$1"
  if [[ "$path" == "~" ]]; then
    echo "$HOME"
  elif [[ "$path" == "~/"* ]]; then
    echo "${HOME}/${path:2}"
  elif [[ "$path" == "~"* ]]; then
    echo "${path/#\~/$HOME}"
  else
    echo "$path"
  fi
}

board_ip() {
  [[ "${1:-}" == "usb" ]] && echo "$BOARD_IP_USB" || echo "$BOARD_IP"
}

ssh_board() {
  ssh "${BOARD_USER}@$(board_ip "${2:-}")" "$1"
}

load_catalog() {
  local file="$1"
  CATALOG_NAMES=()
  CATALOG_PATHS=()

  [[ -f "$file" ]] || return 1

  local line name path
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    name="${line%%[[:space:]]*}"
    path="${line#"$name"}"
    path="${path#"${path%%[![:space:]]*}"}"
    [[ -z "$name" || -z "$path" ]] && continue

    CATALOG_NAMES+=("$name")
    CATALOG_PATHS+=("$path")
  done < "$file"
}

list_catalog() {
  local i
  for i in "${!CATALOG_NAMES[@]}"; do
    printf '  %s  %s\n' "${CATALOG_NAMES[$i]}" "${CATALOG_PATHS[$i]}"
  done
}

catalog_path_raw() {
  local target="$1"
  local file="$2"
  local line name path line_trim

  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_trim="${line%%#*}"
    line_trim="${line_trim#"${line_trim%%[![:space:]]*}"}"
    line_trim="${line_trim%"${line_trim##*[![:space:]]}"}"
    [[ -z "$line_trim" ]] && continue
    name="${line_trim%%[[:space:]]*}"
    path="${line_trim#"$name"}"
    path="${path#"${path%%[![:space:]]*}"}"
    [[ "$name" == "$target" ]] && { echo "$path"; return 0; }
  done < "$file"
  return 1
}

default_catalog_path() {
  case "$1" in
    connect_wifi) echo "~/edge-scripts" ;;
    *) echo "~/edge-${1}" ;;
  esac
}

resolve_catalog_path() {
  local name="$1"
  local catalog="$2"
  local path

  path="$(catalog_path_raw "$name" "$catalog" 2>/dev/null || true)"
  [[ -z "$path" ]] && path="$(default_catalog_path "$name")"
  echo "$path"
}

add_catalog_entry() {
  local file="$1"
  local name="$2"
  local path="$3"
  local tmp="${file}.tmp"
  local line name2 path2 line_trim

  touch "$file"
  : > "$tmp"
  grep '^#' "$file" >> "$tmp" 2>/dev/null || true
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_trim="${line%%#*}"
    line_trim="${line_trim#"${line_trim%%[![:space:]]*}"}"
    line_trim="${line_trim%"${line_trim##*[![:space:]]}"}"
    [[ -z "$line_trim" ]] && continue
    name2="${line_trim%%[[:space:]]*}"
    [[ "$name2" == "$name" ]] && continue
    path2="${line_trim#"$name2"}"
    path2="${path2#"${path2%%[![:space:]]*}"}"
    printf '%s  %s\n' "$name2" "$path2" >> "$tmp"
  done < "$file"
  printf '%s  %s\n' "$name" "$path" >> "$tmp"
  mv "$tmp" "$file"
}

remove_catalog_entry() {
  local file="$1"
  local target="$2"
  local tmp="${file}.tmp"
  local line name path line_trim

  [[ -f "$file" ]] || return 0

  : > "$tmp"
  grep '^#' "$file" >> "$tmp" 2>/dev/null || true
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_trim="${line%%#*}"
    line_trim="${line_trim#"${line_trim%%[![:space:]]*}"}"
    line_trim="${line_trim%"${line_trim##*[![:space:]]}"}"
    [[ -z "$line_trim" ]] && continue
    name="${line_trim%%[[:space:]]*}"
    [[ "$name" == "$target" ]] && continue
    path="${line_trim#"$name"}"
    path="${path#"${path%%[![:space:]]*}"}"
    printf '%s  %s\n' "$name" "$path" >> "$tmp"
  done < "$file"
  mv "$tmp" "$file"
}

clear_catalog() {
  local file="$1"
  grep '^#' "$file" > "${file}.tmp" 2>/dev/null || : > "${file}.tmp"
  mv "${file}.tmp" "$file"
}

edge_script_source() {
  local name="$1"
  local scripts_root="$2"
  local src="${scripts_root}/edge/${name}"
  [[ -e "$src" ]] && { echo "$src"; return 0; }
  return 1
}

list_edge_scripts() {
  local scripts_root="$1"
  local dir="${scripts_root}/edge"
  local item name

  [[ -d "$dir" ]] || return 1
  for item in "$dir"/*; do
    [[ -f "$item" ]] || continue
    name="$(basename "$item")"
    [[ "$name" == "README.md" ]] && continue
    printf '  %s\n' "$name"
  done
}
