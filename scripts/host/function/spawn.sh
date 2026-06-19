# Spawn teardown — undo apt/pip/git/dir side effects on the edge.

teardown_script_spawns() {
  local name="$1" route="$2" password="${3:-}" script spawns kind item extra target
  spawns="$(collect_catalog_spawns "$name" "$CATALOG")"
  [[ -n "$spawns" ]] || return 0
  script="set -euo pipefail"$'\n'
  while IFS=$'\t' read -r kind item extra; do
    [[ -z "$kind" ]] && continue
    case "$kind" in
      apt)
        script+="if dpkg -s \"${item}\" &>/dev/null; then"$'\n'
        script+="  echo \"Removing apt:${item} ...\""$'\n'
        script+="  sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge \"${item}\" 2>/dev/null || sudo apt-get remove -y \"${item}\" 2>/dev/null || true"$'\n'
        script+="else"$'\n'
        script+="  echo \"Skipping apt:${item} (not installed).\""$'\n'
        script+="fi"$'\n'
        ;;
      pip)
        script+="if pip3 show \"${item}\" &>/dev/null; then"$'\n'
        script+="  echo \"Removing pip:${item} ...\""$'\n'
        script+="  sudo pip3 uninstall -y \"${item}\" 2>/dev/null || true"$'\n'
        script+="else"$'\n'
        script+="  echo \"Skipping pip:${item} (not installed).\""$'\n'
        script+="fi"$'\n'
        ;;
      git)
        target="${extra:-$item}"
        script+="if [[ -e \"${target}\" ]]; then"$'\n'
        script+="  echo \"Removing git clone:${target} ...\""$'\n'
        script+="  rm -rf \"${target}\""$'\n'
        script+="else"$'\n'
        script+="  echo \"Skipping git clone:${target} (not present).\""$'\n'
        script+="fi"$'\n'
        ;;
      dir)
        target="${extra:-$item}"
        script+="if [[ -e \"${target}\" ]]; then"$'\n'
        script+="  echo \"Removing dir:${target} ...\""$'\n'
        script+="  rm -rf \"${target}\""$'\n'
        script+="else"$'\n'
        script+="  echo \"Skipping dir:${target} (not present).\""$'\n'
        script+="fi"$'\n'
        ;;
    esac
  done <<< "$spawns"
  board_ssh_stdin "$route" "$password" "$script"
}
