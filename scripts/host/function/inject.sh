# Inject edge scripts onto the board.

inject_script() {
  local name="$1" src path route
  src="$(edge_script_path "$name")" || die "Edge script not found: edge/${name}"
  path="$(resolve_install_path "$name" "$CATALOG")"
  pick_route || die "Could not reach board (LAN ${BOARD_IP}, USB ${BOARD_IP_USB})."
  route="$BOARD_ROUTE"
  board_ensure_host_key "$route"
  echo "Injecting ${name} -> ${path} ($(board_ip "$route")) ..."
  if board_auth_ok "$route"; then
    board_ssh "mkdir -p ${path}" "$route"
    board_scp "$src" "${path}/" "$route"
    board_ssh "chmod +x ${path}/${name}" "$route"
  else
    inject_via_single_ssh "$name" "$src" "$path" "$route" || die "Inject failed."
  fi
  add_catalog_entry "$CATALOG" "$name" "$path"
  inject_declared_spawns "$name"
  echo "Injected ${name} -> ${path}"
  list_catalog "$CATALOG"
}
