# Board connectivity — LAN first, then USB.

board_ip() { [[ "${1:-}" == "usb" ]] && echo "$BOARD_IP_USB" || echo "$BOARD_IP"; }
board_timeout() { [[ "${1:-}" == "usb" ]] && echo 10 || echo 5; }

board_host_key_failed() {
  [[ "$1" == *"Host key verification failed"* || "$1" == *"REMOTE HOST IDENTIFICATION HAS CHANGED"* ]]
}

board_clear_host_key() {
  local ip="$1"
  command -v ssh-keygen >/dev/null 2>&1 || return 0
  echo "Removing stale SSH host key for ${ip} ..." >&2
  ssh-keygen -R "$ip" 2>/dev/null || true
}

# Probe SSH before interactive login; clears changed keys from known_hosts.
board_ensure_host_key() {
  local route="$1" ip_host ip timeout err
  ip_host="$(board_ip "$route")"
  ip="${BOARD_USER}@${ip_host}"
  timeout="$(board_timeout "$route")"
  err="$(ssh -o BatchMode=yes -o "ConnectTimeout=${timeout}" "$ip" true 2>&1)" || true
  if board_host_key_failed "$err"; then
    board_clear_host_key "$ip_host"
  fi
}

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
