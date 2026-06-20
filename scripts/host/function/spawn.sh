# Spawn teardown — undo apt/pip/git/dir side effects on the edge.
# Order: pip → git/dir → apt → post-cleanup (cache, autoremove, daemon-reload).

_spawn_pip_services() {
  case "$1" in
    jetson-stats) echo "jtop.service" ;;
    *) echo "${1}.service" ;;
  esac
}

_append_pip_teardown() {
  local script_ref="$1" item="$2" svc
  svc="$(_spawn_pip_services "$item")"
  printf -v "$script_ref" '%s' "${!script_ref}"
  printf -v "$script_ref" '%sif pip3 show "%s" &>/dev/null; then\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%s  echo "Stopping services for pip:%s ..."\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%s  sudo systemctl stop %s 2>/dev/null || true\n' "${!script_ref}" "$svc"
  printf -v "$script_ref" '%s  sudo systemctl disable %s 2>/dev/null || true\n' "${!script_ref}" "$svc"
  printf -v "$script_ref" '%s  echo "Removing pip:%s ..."\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%s  if ! sudo pip3 uninstall -y "%s" 2>/dev/null; then\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%s    echo "Failed pip:%s" >&2\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%s    failures=$((failures+1))\n' "${!script_ref}"
  printf -v "$script_ref" '%s  fi\n' "${!script_ref}"
  printf -v "$script_ref" '%selse\n' "${!script_ref}"
  printf -v "$script_ref" '%s  echo "Skipping pip:%s (not installed)."\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%sfi\n' "${!script_ref}"
}

_append_path_teardown() {
  local script_ref="$1" kind="$2" target="$3"
  printf -v "$script_ref" '%s' "${!script_ref}"
  printf -v "$script_ref" '%starget="%s"\n' "${!script_ref}" "$target"
  printf -v "$script_ref" '%s[[ "$target" == ~* ]] && target="${HOME}${target:1}"\n' "${!script_ref}"
  printf -v "$script_ref" '%sif [[ -e "$target" ]]; then\n' "${!script_ref}"
  printf -v "$script_ref" '%s  echo "Removing %s:$target ..."\n' "${!script_ref}" "$kind"
  printf -v "$script_ref" '%s  if ! sudo rm -rf "$target"; then\n' "${!script_ref}"
  printf -v "$script_ref" '%s    echo "Failed %s:$target" >&2\n' "${!script_ref}" "$kind"
  printf -v "$script_ref" '%s    failures=$((failures+1))\n' "${!script_ref}"
  printf -v "$script_ref" '%s  fi\n' "${!script_ref}"
  printf -v "$script_ref" '%selse\n' "${!script_ref}"
  printf -v "$script_ref" '%s  echo "Skipping %s:$target (not present)."\n' "${!script_ref}" "$kind"
  printf -v "$script_ref" '%sfi\n' "${!script_ref}"
}

_append_apt_teardown() {
  local script_ref="$1" item="$2"
  printf -v "$script_ref" '%s' "${!script_ref}"
  printf -v "$script_ref" '%sif dpkg -s "%s" &>/dev/null; then\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%s  echo "Removing apt:%s ..."\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%s  if ! sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge "%s" 2>/dev/null && ! sudo apt-get remove -y "%s" 2>/dev/null; then\n' \
    "${!script_ref}" "$item" "$item"
  printf -v "$script_ref" '%s    echo "Failed apt:%s" >&2\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%s    failures=$((failures+1))\n' "${!script_ref}"
  printf -v "$script_ref" '%s  fi\n' "${!script_ref}"
  printf -v "$script_ref" '%selse\n' "${!script_ref}"
  printf -v "$script_ref" '%s  echo "Skipping apt:%s (not installed)."\n' "${!script_ref}" "$item"
  printf -v "$script_ref" '%sfi\n' "${!script_ref}"
}

_append_pip_post_teardown() {
  local script_ref="$1"
  printf -v "$script_ref" '%s' "${!script_ref}"
  printf -v "$script_ref" '%secho "Purging pip cache ..."\n' "${!script_ref}"
  printf -v "$script_ref" '%sif ! sudo pip3 cache purge 2>/dev/null; then\n' "${!script_ref}"
  printf -v "$script_ref" '%s  sudo rm -rf /root/.cache/pip "${HOME}/.cache/pip" 2>/dev/null || true\n' "${!script_ref}"
  printf -v "$script_ref" '%sfi\n' "${!script_ref}"
  printf -v "$script_ref" '%secho "Reloading systemd ..."\n' "${!script_ref}"
  printf -v "$script_ref" '%ssudo systemctl daemon-reload 2>/dev/null || true\n' "${!script_ref}"
}

_append_apt_post_teardown() {
  local script_ref="$1"
  printf -v "$script_ref" '%s' "${!script_ref}"
  printf -v "$script_ref" '%secho "Running apt autoremove ..."\n' "${!script_ref}"
  printf -v "$script_ref" '%sif ! sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>/dev/null; then\n' "${!script_ref}"
  printf -v "$script_ref" '%s  echo "Failed apt:autoremove" >&2\n' "${!script_ref}"
  printf -v "$script_ref" '%s  failures=$((failures+1))\n' "${!script_ref}"
  printf -v "$script_ref" '%sfi\n' "${!script_ref}"
  printf -v "$script_ref" '%secho "Running apt autoclean ..."\n' "${!script_ref}"
  printf -v "$script_ref" '%sif ! sudo DEBIAN_FRONTEND=noninteractive apt-get autoclean -y 2>/dev/null; then\n' "${!script_ref}"
  printf -v "$script_ref" '%s  echo "Failed apt:autoclean" >&2\n' "${!script_ref}"
  printf -v "$script_ref" '%s  failures=$((failures+1))\n' "${!script_ref}"
  printf -v "$script_ref" '%sfi\n' "${!script_ref}"
}

teardown_script_spawns() {
  local name="$1" route="$2" password="${3:-}"
  local script spawns kind item extra target
  local -a pip_items=() apt_items=()
  local -a git_paths=() dir_paths=()
  local had_pip=0 had_apt=0

  spawns="$(collect_catalog_spawns "$name" "$CATALOG")"
  [[ -n "$spawns" ]] || return 0

  while IFS=$'\t' read -r kind item extra; do
    [[ -z "$kind" ]] && continue
    case "$kind" in
      pip) pip_items+=("$item"); had_pip=1 ;;
      apt) apt_items+=("$item"); had_apt=1 ;;
      git) git_paths+=("${extra:-$item}") ;;
      dir) dir_paths+=("${extra:-$item}") ;;
    esac
  done <<< "$spawns"

  script="set -uo pipefail"$'\n'
  script+="sudo -n true 2>/dev/null || sudo -v"$'\n'
  script+="failures=0"$'\n'

  for item in "${pip_items[@]}"; do
    _append_pip_teardown script "$item"
  done
  for target in "${git_paths[@]}"; do
    _append_path_teardown script git "$target"
  done
  for target in "${dir_paths[@]}"; do
    _append_path_teardown script dir "$target"
  done
  for item in "${apt_items[@]}"; do
    _append_apt_teardown script "$item"
  done
  (( had_pip )) && _append_pip_post_teardown script
  (( had_apt )) && _append_apt_post_teardown script

  script+="if (( failures > 0 )); then"$'\n'
  script+="  echo \"Spawn teardown failed (\$failures step(s)).\" >&2"$'\n'
  script+="  exit 1"$'\n'
  script+="fi"$'\n'
  board_ssh_stdin "$route" "$password" "$script"
}
