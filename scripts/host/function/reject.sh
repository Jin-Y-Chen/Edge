# Reject injected scripts and tear down catalog spawns.

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

_reject_script_route() {
  local name="$1" catalog="$2" route="$3" password="${4:-${BOARD_SSH_PASSWORD:-}}" path
  path="$(catalog_path "$name" "$catalog")" || return 1
  teardown_script_spawns "$name" "$route" "$password" || true
  if board_ssh "rm -f ${path}/${name}" "$route" "$password"; then
    remove_catalog_block "$catalog" "$name"
    echo "Rejected ${name} (${path}/${name}) via ${route}."
    return 0
  fi
  return 1
}

_reject_route() {
  local catalog="$1" route="$2" password="${3:-}"
  local -a names=()
  local name
  (( ${#CATALOG_NAMES[@]} )) || return 0
  names=("${CATALOG_NAMES[@]}")
  for name in "${names[@]}"; do
    _reject_script_route "$name" "$catalog" "$route" "$password" || \
      echo "  Failed ${name} via ${route}." >&2
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

  trap board_session_end RETURN
  [[ -n "$password" && -z "${BOARD_SSH_PASSWORD:-}" ]] && BOARD_SSH_PASSWORD="$password"

  for route in lan usb; do
    load_catalog "$catalog" || break
    board_port_open "$route" || continue
    if ! board_auth_ok "$route"; then
      [[ -z "${BOARD_SSH_PASSWORD:-}" ]] && board_session_begin "$route"
    fi
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
  local name="$1" password="${2:-}" path route
  path="$(catalog_path "$name" "$CATALOG")" || die "Not in catalog: ${name}"
  trap board_session_end RETURN
  for route in lan usb; do
    board_port_open "$route" || continue
    [[ -n "$password" || -n "${BOARD_SSH_PASSWORD:-}" ]] || board_session_begin "$route"
    if _reject_script_route "$name" "$CATALOG" "$route" "$password"; then
      return 0
    fi
  done
  echo "Could not reject ${name} via LAN or USB." >&2
  return 1
}
