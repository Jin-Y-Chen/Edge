# SSH session, remote commands, and file upload.

board_auth_ok() {
  local route="$1" ip timeout
  ip="${BOARD_USER}@$(board_ip "$route")"
  timeout="$(board_timeout "$route")"
  ssh -o BatchMode=yes -o "ConnectTimeout=${timeout}" -o StrictHostKeyChecking=accept-new \
    "$ip" true 2>/dev/null
}

board_prompt_password_once() {
  [[ -n "${BOARD_SSH_PASSWORD:-}" ]] && return 0
  if [[ -n "${SSHPASS:-}" ]]; then
    BOARD_SSH_PASSWORD="$SSHPASS"
    return 0
  fi
  local pass
  if ! read -rs -p "SSH password for ${BOARD_USER}@Jetson (once): " pass; then
    echo "" >&2
    die "Password input failed."
  fi
  echo ""
  [[ -n "$pass" ]] || die "SSH password cannot be empty."
  BOARD_SSH_PASSWORD="$pass"
}

board_prompt_sudo_once() {
  [[ -n "${BOARD_SUDO_PASSWORD:-}" ]] && return 0
  local pass
  if ! read -rs -p "Sudo password for ${BOARD_USER}@Jetson (once): " pass; then
    echo "" >&2
    die "Sudo password input failed."
  fi
  echo ""
  [[ -n "$pass" ]] || die "Sudo password cannot be empty."
  BOARD_SUDO_PASSWORD="$pass"
}

board_session_begin() {
  local route="$1"
  board_ensure_host_key "$route"
  board_auth_ok "$route" && return 0
  board_prompt_password_once
}

board_session_end() {
  unset BOARD_SSH_PASSWORD BOARD_SUDO_PASSWORD
}

board_run_ssh() {
  local ip="$1" password="$2" timeout="$3"
  shift 3
  local -a opts=(-o "ConnectTimeout=${timeout}" -o StrictHostKeyChecking=accept-new)
  local -a tty=()
  [[ "${BOARD_SSH_ALLOCATE_TTY:-}" == 1 ]] && tty=(-tt)
  local passfile askpass status

  if [[ -z "$password" ]]; then
    ssh "${opts[@]}" "${tty[@]}" "$ip" "$@"
    return $?
  fi
  if command -v sshpass >/dev/null 2>&1; then
    SSHPASS="$password" sshpass -e ssh "${opts[@]}" "${tty[@]}" -o BatchMode=yes -o PubkeyAuthentication=no \
      "$ip" "$@"
    return $?
  fi

  passfile="$(mktemp)"
  askpass="$(mktemp)"
  chmod 600 "$passfile"
  printf '%s' "$password" > "$passfile"
  printf '#!/bin/sh\ncat "%s"\n' "$passfile" > "$askpass"
  chmod 700 "$askpass"
  DISPLAY="${DISPLAY:-:0}" SSH_ASKPASS="$askpass" SSH_ASKPASS_REQUIRE=force \
    ssh "${opts[@]}" "${tty[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no \
    "$ip" "$@"
  status=$?
  rm -f "$askpass" "$passfile"
  return $status
}

board_ssh() {
  local cmd="$1" route="$2" password="${3:-${BOARD_SSH_PASSWORD:-}}"
  local ip_host ip timeout err errfile attempt=0 status
  ip_host="$(board_ip "$route")"
  ip="${BOARD_USER}@${ip_host}"
  timeout="$(board_timeout "$route")"
  errfile="$(mktemp)"

  while (( attempt < 2 )); do
    status=0
    board_run_ssh "$ip" "$password" "$timeout" "$cmd" 2>"$errfile" || status=$?
    if [[ $status -eq 0 ]]; then
      rm -f "$errfile"
      return 0
    fi
    err="$(<"$errfile")"
    cat "$errfile" >&2
    if board_host_key_failed "$err" && (( attempt == 0 )); then
      board_clear_host_key "$ip_host"
      attempt=1
      continue
    fi
    rm -f "$errfile"
    return $status
  done
  rm -f "$errfile"
  return 1
}

board_scp() {
  local src="$1" dest="$2" route="$3" password="${4:-${BOARD_SSH_PASSWORD:-}}"
  local ip_host err errfile attempt=0 status remote_file
  ip_host="$(board_ip "$route")"
  errfile="$(mktemp)"
  remote_file="${dest%/}/$(basename "$src")"

  while (( attempt < 2 )); do
    status=0
    sed 's/\r$//' < "$src" | board_run_ssh "${BOARD_USER}@${ip_host}" "$password" "$(board_timeout "$route")" \
      "cat > ${remote_file}" 2>"$errfile" || status=$?
    if [[ $status -eq 0 ]]; then
      rm -f "$errfile"
      return 0
    fi
    err="$(<"$errfile")"
    cat "$errfile" >&2
    if board_host_key_failed "$err" && (( attempt == 0 )); then
      board_clear_host_key "$ip_host"
      attempt=1
      continue
    fi
    rm -f "$errfile"
    return $status
  done
  rm -f "$errfile"
  return 1
}

board_ssh_stdin() {
  local route="$1" password="${2:-${BOARD_SSH_PASSWORD:-}}" script="${3:?}"
  local ip_host ip timeout err errfile attempt=0 status remote
  ip_host="$(board_ip "$route")"
  ip="${BOARD_USER}@${ip_host}"
  timeout="$(board_timeout "$route")"
  remote="/tmp/edge-spawn-$$-${RANDOM}.sh"
  errfile="$(mktemp)"

  while (( attempt < 2 )); do
    status=0
    : >"$errfile"
    printf '%s' "$script" | board_run_ssh "$ip" "$password" "$timeout" \
      "cat > ${remote} && chmod 700 ${remote}" 2>"$errfile" || status=$?
    if [[ $status -ne 0 ]]; then
      err="$(<"$errfile")"
      [[ -n "$err" ]] && cat "$errfile" >&2
      if board_host_key_failed "$err" && (( attempt == 0 )); then
        board_clear_host_key "$ip_host"
        attempt=1
        continue
      fi
      rm -f "$errfile"
      return $status
    fi

    BOARD_SSH_ALLOCATE_TTY=1
    board_run_ssh "$ip" "$password" "$timeout" \
      "bash ${remote}; ec=\$?; rm -f ${remote}; exit \$ec" 2>"$errfile" || status=$?
    unset BOARD_SSH_ALLOCATE_TTY

    if [[ $status -eq 0 ]]; then
      rm -f "$errfile"
      return 0
    fi
    err="$(<"$errfile")"
    [[ -n "$err" ]] && cat "$errfile" >&2
    if board_host_key_failed "$err" && (( attempt == 0 )); then
      board_clear_host_key "$ip_host"
      attempt=1
      continue
    fi
    rm -f "$errfile"
    return $status
  done
  rm -f "$errfile"
  return 1
}

inject_via_single_ssh() {
  local name="$1" src="$2" path="$3" route="$4" ip timeout remote
  ip="${BOARD_USER}@$(board_ip "$route")"
  timeout="$(board_timeout "$route")"
  remote="${path%/}/${name}"

  ssh -o "ConnectTimeout=${timeout}" -o StrictHostKeyChecking=accept-new \
    "$ip" bash -s <<EOF
mkdir -p ${path}
base64 -d > ${remote} <<'B64EOF'
$(sed 's/\r$//' "$src" | base64)
B64EOF
chmod +x ${remote}
EOF
}
