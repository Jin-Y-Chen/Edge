# Shared helpers — die, prompts, line trimming.

die() { echo "$*" >&2; exit 1; }

confirm_yes() {
  local answer
  read -rp "$1" answer
  [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]]
}

trim_line() {
  local line="$1"
  line="${line//$'\r'/}"
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  printf '%s' "$line"
}
