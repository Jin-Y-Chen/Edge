#!/usr/bin/env bash
# Host library — source from host/* scripts after setting HOST_LIB path.

# --- init ---

host_init() {
  local caller="${1:-${BASH_SOURCE[1]}}"
  HOST_DIR="$(cd "$(dirname "$caller")" && pwd)"
  SCRIPTS_DIR="$(cd "$HOST_DIR/.." && pwd)"
  REPO_DIR="$(cd "$HOST_DIR/../.." && pwd)"
  # shellcheck source=../../config.sh
  source "$SCRIPTS_DIR/config.sh"
  CATALOG="${SCRIPTS_DIR}/catalog.list"
  EDGE_DIR="${SCRIPTS_DIR}/edge"
}

die() { echo "$*" >&2; exit 1; }

confirm_yes() {
  local answer
  read -rp "$1" answer
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

# --- board connectivity (LAN first, then USB) ---

board_ip() { [[ "${1:-}" == "usb" ]] && echo "$BOARD_IP_USB" || echo "$BOARD_IP"; }
board_timeout() { [[ "${1:-}" == "usb" ]] && echo 10 || echo 5; }

board_port_open() {
  local route="$1" ip timeout
  ip="$(board_ip "$route")"
  timeout="$(board_timeout "$route")"
  command -v nc >/dev/null 2>&1 && nc -z -w "$timeout" "$ip" 22 &>/dev/null && return 0
  (echo >/dev/tcp/"$ip"/22) &>/dev/null
}

pick_route() {
  local route
  BOARD_ROUTE=""
  for route in lan usb; do
    if board_port_open "$route"; then
      BOARD_ROUTE="$route"
      return 0
    fi
    echo "Port 22 closed: ${route} ($(board_ip "$route"))." >&2
  done
  return 1
}

board_ssh() {
  local cmd="$1" route="$2" password="${3:-}"
  local ip="${BOARD_USER}@$(board_ip "$route")"
  local timeout; timeout="$(board_timeout "$route")"
  local -a opts=(-o "ConnectTimeout=${timeout}")

  if [[ -z "$password" ]]; then
    ssh "${opts[@]}" "$ip" "$cmd"
    return $?
  fi

  if command -v sshpass >/dev/null 2>&1; then
    SSHPASS="$password" sshpass -e ssh "${opts[@]}" -o BatchMode=yes \
      -o StrictHostKeyChecking=accept-new "$ip" "$cmd"
    return $?
  fi

  local passfile askpass status
  passfile="$(mktemp)"
  askpass="$(mktemp)"
  chmod 600 "$passfile"
  printf '%s' "$password" > "$passfile"
  printf '#!/bin/sh\ncat %s\n' "$passfile" > "$askpass"
  chmod 700 "$askpass"
  DISPLAY="${DISPLAY:-:0}" SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force \
    ssh "${opts[@]}" -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$ip" "$cmd"
  status=$?
  rm -f "$askpass" "$passfile"
  [[ $status -ne 0 ]] && echo "Hint: install sshpass for password SSH." >&2
  return $status
}

board_scp() {
  local src="$1" dest="$2" route="$3"
  scp -o "ConnectTimeout=$(board_timeout "$route")" \
    "$src" "${BOARD_USER}@$(board_ip "$route"):${dest}"
}

remove_on_edge() {
  local path="$1" password="${2:-}" route
  for route in lan usb; do
    board_port_open "$route" || continue
    if board_ssh "rm -rf ${path}" "$route" "$password"; then
      echo "Removed ${path} via ${route} ($(board_ip "$route"))."
      return 0
    fi
  done
  echo "Could not reach board via LAN or USB." >&2
  return 1
}

# --- catalog ---

trim_line() {
  local line="$1"
  line="${line//$'\r'/}"
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}

load_catalog() {
  local file="$1" line name path
  CATALOG_NAMES=()
  CATALOG_PATHS=()
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(trim_line "$line")"
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

catalog_path() {
  local name="$1" file="$2" line trimmed n p
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_line "$line")"
    [[ -z "$trimmed" ]] && continue
    n="${trimmed%%[[:space:]]*}"
    p="${trimmed#"$n"}"
    p="${p#"${p%%[![:space:]]*}"}"
    [[ "$n" == "$name" ]] && { echo "$p"; return 0; }
  done < "$file"
  return 1
}

resolve_install_path() {
  local name="$1" catalog="$2" path
  path="$(catalog_path "$name" "$catalog" 2>/dev/null || true)"
  echo "${path:-${EDGE_ROOT:-~/Edge}}"
}

_catalog_header() {
  local file="$1" tmp="$2"
  grep '^#' "$file" > "$tmp" 2>/dev/null || : > "$tmp"
}

add_catalog_entry() {
  local file="$1" name="$2" path="$3" tmp="${file}.tmp" line n p t
  touch "$file"
  _catalog_header "$file" "$tmp"
  while IFS= read -r line || [[ -n "$line" ]]; do
    t="$(trim_line "$line")"
    [[ -z "$t" ]] && continue
    n="${t%%[[:space:]]*}"
    [[ "$n" == "$name" ]] && continue
    p="${t#"$n"}"
    p="${p#"${p%%[![:space:]]*}"}"
    printf '%s  %s\n' "$n" "$p" >> "$tmp"
  done < "$file"
  printf '%s  %s\n' "$name" "$path" >> "$tmp"
  mv "$tmp" "$file"
}

remove_catalog_entry() {
  local file="$1" drop="$2" tmp="${file}.tmp" line n p t
  [[ -f "$file" ]] || return 0
  _catalog_header "$file" "$tmp"
  while IFS= read -r line || [[ -n "$line" ]]; do
    t="$(trim_line "$line")"
    [[ -z "$t" ]] && continue
    n="${t%%[[:space:]]*}"
    [[ "$n" == "$drop" ]] && continue
    p="${t#"$n"}"
    p="${p#"${p%%[![:space:]]*}"}"
    printf '%s  %s\n' "$n" "$p" >> "$tmp"
  done < "$file"
  mv "$tmp" "$file"
}

# --- inject / reject ---

edge_script_name() {
  local name="$1"
  [[ "$name" == *.sh ]] || name="${name}.sh"
  echo "$name"
}

edge_script_path() {
  local name path
  name="$(edge_script_name "$1")"
  path="${EDGE_DIR}/${name}"
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

inject_script() {
  local name="$1" src path remote
  remote="$(edge_script_name "$name")"
  src="$(edge_script_path "$name")" || die "Edge script not found: edge/${remote}"
  path="$(resolve_install_path "$remote" "$CATALOG")"
  pick_route || die "Could not reach board (LAN ${BOARD_IP}, USB ${BOARD_IP_USB})."
  echo "Injecting ${remote} -> ${path} ($(board_ip "$BOARD_ROUTE")) ..."
  board_ssh "mkdir -p ${path}" "$BOARD_ROUTE"
  board_scp "$src" "${path}/" "$BOARD_ROUTE"
  board_ssh "chmod +x ${path}/${remote}" "$BOARD_ROUTE"
  add_catalog_entry "$CATALOG" "$remote" "$path"
  echo "Injected ${remote} -> ${path}"
}

_reject_route() {
  local catalog="$1" route="$2" password="${3:-}"
  local -a names=("${CATALOG_NAMES[@]}")
  local name path
  for name in "${names[@]}"; do
    path="$(catalog_path "$name" "$catalog")" || continue
    if board_ssh "rm -rf ${path}" "$route" "$password"; then
      remove_catalog_entry "$catalog" "$name"
      echo "Rejected ${name} (${path}) via ${route}."
    else
      echo "  Failed ${name} via ${route}." >&2
    fi
  done
}

# LAN then USB; update catalog per success. Empty catalog => Edge cleaned.
reject_all_catalog() {
  local catalog="$1" password="${2:-}" confirm="${3:-0}" route

  if ! load_catalog "$catalog"; then
    echo "Edge cleaned."
    return 0
  fi

  echo "Catalog:"
  list_catalog
  echo ""
  if [[ "$confirm" == 1 ]]; then
    confirm_yes "Reject all on edge? [y/N] " || { echo "Cancelled."; return 1; }
  fi

  for route in lan usb; do
    load_catalog "$catalog" || break
    echo "Trying ${route} ($(board_ip "$route")) ..."
    _reject_route "$catalog" "$route" "$password"
  done

  if load_catalog "$catalog"; then
    echo "Error: could not reject all entries:" >&2
    list_catalog >&2
    return 1
  fi
  echo "Edge cleaned."
  return 0
}

reject_one() {
  local name="$1" password="${2:-}" path
  name="$(edge_script_name "$name")"
  path="$(catalog_path "$name" "$CATALOG")" || die "Not in catalog: ${name}"
  remove_on_edge "$path" "$password" || return 1
  remove_catalog_entry "$CATALOG" "$name"
  echo "Rejected ${name} (${path})"
}
