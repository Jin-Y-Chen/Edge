#!/usr/bin/env bash
# Shared helpers for host inject / reject / uninstall.

trim_catalog_line() {
  local line="$1"
  line="${line//$'\r'/}"
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}

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

ssh_board_quick() {
  local cmd="$1"
  local target="$2"
  ssh -o ConnectTimeout=5 -o BatchMode=yes "${BOARD_USER}@$(board_ip "$target")" "$cmd"
}

# Interactive SSH — prompts for password when keys are not configured.
ssh_board_interactive() {
  local cmd="$1"
  local target="$2"
  ssh -o ConnectTimeout=5 "${BOARD_USER}@$(board_ip "$target")" "$cmd"
}

# SSH with a password supplied by the caller (uninstall passes it per call).
ssh_board_with_password() {
  local cmd="$1"
  local target="$2"
  local password="$3"
  local ip="${BOARD_USER}@$(board_ip "$target")"
  local -a opts=(-o ConnectTimeout=5)
  local askpass passfile status

  if [[ -z "$password" ]]; then
    ssh_board_interactive "$cmd" "$target"
    return $?
  fi

  if command -v sshpass >/dev/null 2>&1; then
    SSHPASS="$password" sshpass -e ssh "${opts[@]}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$ip" "$cmd"
    return $?
  fi

  passfile="$(mktemp)"
  askpass="$(mktemp)"
  chmod 600 "$passfile"
  printf '%s' "$password" > "$passfile"
  cat > "$askpass" <<EOF
#!/bin/sh
cat '$passfile'
EOF
  chmod 700 "$askpass"
  DISPLAY="${DISPLAY:-:0}" SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force \
    ssh "${opts[@]}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$ip" "$cmd"
  status=$?
  rm -f "$askpass" "$passfile"
  return $status
}

PICKED_BOARD_TARGET=""

pick_board_target() {
  local t
  PICKED_BOARD_TARGET=""
  for t in lan usb; do
    if ssh_board_quick true "$t" 2>/dev/null; then
      PICKED_BOARD_TARGET="$t"
      return 0
    fi
    echo "Unreachable via ${t} ($(board_ip "$t"))." >&2
  done
  return 1
}

scp_to_board() {
  local src="$1"
  local dest="$2"
  local target="$3"
  scp -o ConnectTimeout=5 -o BatchMode=yes "$src" "${BOARD_USER}@$(board_ip "$target"):${dest}"
}

remove_path_on_edge_any() {
  local path="$1"
  local t

  for t in lan usb; do
    if ssh_board_interactive "rm -rf ${path}" "$t"; then
      echo "Removed ${path} on edge (${t}: $(board_ip "$t"))."
      return 0
    fi
    echo "  Unreachable via ${t} ($(board_ip "$t"))." >&2
  done

  echo "Warning: could not remove ${path} on edge (tried LAN and USB)." >&2
  return 1
}

load_catalog() {
  local file="$1"
  CATALOG_NAMES=()
  CATALOG_PATHS=()

  [[ -f "$file" ]] || return 1

  local line name path
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim_catalog_line "$line")"
    [[ -z "$line" ]] && continue

    name="${line%%[[:space:]]*}"
    path="${line#"$name"}"
    path="${path#"${path%%[![:space:]]*}"}"
    [[ -z "$name" || -z "$path" ]] && continue

    CATALOG_NAMES+=("$name")
    CATALOG_PATHS+=("$path")
  done < "$file"

  [[ ${#CATALOG_NAMES[@]} -gt 0 ]]
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
    line_trim="$(trim_catalog_line "$line")"
    [[ -z "$line_trim" ]] && continue
    name="${line_trim%%[[:space:]]*}"
    path="${line_trim#"$name"}"
    path="${path#"${path%%[![:space:]]*}"}"
    [[ "$name" == "$target" ]] && { echo "$path"; return 0; }
  done < "$file"
  return 1
}

default_catalog_path() {
  echo "${EDGE_ROOT:-~/Edge}"
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
    line_trim="$(trim_catalog_line "$line")"
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
    line_trim="$(trim_catalog_line "$line")"
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

reject_catalog_via_target() {
  local catalog="$1"
  local target="$2"
  local ssh_password="${3:-}"
  local -a names=()
  local name path

  load_catalog "$catalog" || return 0

  names=("${CATALOG_NAMES[@]}")

  for name in "${names[@]}"; do
    path="$(catalog_path_raw "$name" "$catalog")" || continue
    if ssh_board_with_password "rm -rf ${path}" "$target" "$ssh_password"; then
      remove_catalog_entry "$catalog" "$name"
      echo "Rejected ${name} (${path}) via ${target} ($(board_ip "$target"))."
    else
      echo "  Failed ${name} via ${target} ($(board_ip "$target"))." >&2
    fi
  done
}

# Uninstall: LAN first, then USB; update catalog per successful removal.
# Optional ssh_password (from uninstall only) is reused for every SSH attempt.
# Returns 0 with "Edge cleaned." when catalog is empty, 1 if entries remain.
reject_all_for_uninstall() {
  local catalog="$1"
  local ssh_password="${2:-}"

  if ! load_catalog "$catalog"; then
    echo "Edge cleaned."
    return 0
  fi

  echo "Catalog entries to reject:"
  list_catalog
  echo ""

  echo "Trying LAN (${BOARD_IP}) ..."
  reject_catalog_via_target "$catalog" lan "$ssh_password"

  if load_catalog "$catalog"; then
    echo ""
    echo "Trying USB (${BOARD_IP_USB}) ..."
    reject_catalog_via_target "$catalog" usb "$ssh_password"
  fi

  if load_catalog "$catalog"; then
    echo ""
    echo "Error: could not reject all catalog entries via LAN or USB:" >&2
    list_catalog >&2
    return 1
  fi

  echo "Edge cleaned."
  return 0
}

reject_all_on_edge() {
  local catalog="$1"
  local auto_confirm="${2:-0}"
  local paths=()
  local path existing i

  add_reject_path() {
    local candidate="$1"
    [[ -z "$candidate" ]] && return
    for existing in "${paths[@]}"; do
      [[ "$existing" == "$candidate" ]] && return
    done
    paths+=("$candidate")
  }

  if load_catalog "$catalog"; then
    echo "Catalog entries to reject:"
    list_catalog
    echo ""
  else
    echo "No catalog entries in ${catalog}."
    echo ""
  fi

  if [[ "$auto_confirm" -ne 1 ]]; then
    read -rp "Reject all injected solutions on edge? [y/N] " confirm
    [[ "${confirm,,}" == "y" || "${confirm,,}" == "yes" ]] || { echo "Cancelled."; return 1; }
  fi

  if load_catalog "$catalog"; then
    for i in "${!CATALOG_NAMES[@]}"; do
      add_reject_path "${CATALOG_PATHS[$i]}"
    done
  fi
  add_reject_path "${EDGE_ROOT:-~/Edge}"

  if [[ ${#paths[@]} -eq 0 ]]; then
    echo "Nothing to remove on edge."
  else
    for path in "${paths[@]}"; do
      remove_path_on_edge_any "$path" || true
    done
  fi

  clear_catalog "$catalog"
  echo "Cleared ${catalog}."
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
