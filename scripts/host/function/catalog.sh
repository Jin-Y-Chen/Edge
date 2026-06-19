# Catalog log — injected scripts and declared spawns.

catalog_timestamp() { date +%d/%m/%y--%H:%M--; }

_catalog_header() {
  local file="$1" tmp="$2"
  grep '^#' "$file" > "$tmp" 2>/dev/null || : > "$tmp"
}

inject_declared_spawns() {
  local name="$1" src line rest kind item extra
  src="$(edge_script_path "$name")" || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ "$line" == \#* ]] || continue
    line="${line#\#}"
    line="${line#"${line%%[![:space:]]*}"}"
    [[ "${line%%[[:space:]]*}" == "spawn" ]] || continue
    rest="${line#spawn}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    kind="${rest%%[[:space:]]*}"
    rest="${rest#"$kind"}"
    rest="${rest#"${rest%%[![:space:]]*}"}"
    item="${rest%%[[:space:]]*}"
    extra="${rest#"$item"}"
    extra="${extra#"${extra%%[![:space:]]*}"}"
    [[ -n "$kind" && -n "$item" ]] || continue
    append_catalog_spawn "$CATALOG" "$name" "$kind" "$item" "$extra" || true
  done < "$src"
}

_parse_entry_name() {
  local line="$1" rest
  [[ "$line" == *"|"* ]] || return 1
  rest="${line#*|}"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  printf '%s' "${rest%%[[:space:]]*}"
}

_parse_entry_path() {
  local line="$1" rest name
  [[ "$line" == *"|"* ]] || return 1
  rest="${line#*|}"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  name="${rest%%[[:space:]]*}"
  rest="${rest#"$name"}"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  printf '%s' "$rest"
}

_is_spawn_line() {
  local line="$1"
  line="${line#"${line%%[![:space:]]*}"}"
  [[ "$line" == ">"* ]]
}

# Host catalog spawn: > KIND  ITEM  [EXTRA]
_parse_spawn_fields() {
  local line="$1"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line#>}"
  line="${line#"${line%%[![:space:]]*}"}"
  SPAWN_SCRIPT=""
  SPAWN_KIND="${line%%[[:space:]]*}"
  line="${line#"$SPAWN_KIND"}"
  line="${line#"${line%%[![:space:]]*}"}"
  case "$SPAWN_KIND" in
    apt|pip|git|dir)
      SPAWN_ITEM="${line%%[[:space:]]*}"
      line="${line#"$SPAWN_ITEM"}"
      line="${line#"${line%%[![:space:]]*}"}"
      SPAWN_EXTRA="$line"
      ;;
    *)
      SPAWN_SCRIPT="$SPAWN_KIND"
      SPAWN_KIND="${line%%[[:space:]]*}"
      line="${line#"$SPAWN_KIND"}"
      line="${line#"${line%%[![:space:]]*}"}"
      SPAWN_ITEM="${line%%[[:space:]]*}"
      line="${line#"$SPAWN_ITEM"}"
      line="${line#"${line%%[![:space:]]*}"}"
      SPAWN_EXTRA="$line"
      ;;
  esac
}

_spawn_key() {
  printf '%s|%s|%s' "$SPAWN_KIND" "$SPAWN_ITEM" "${SPAWN_EXTRA:-}"
}

_catalog_has_spawn() {
  local file="$1" want="$2" line trimmed
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_line "$line")"
    [[ -z "$trimmed" ]] || ! _is_spawn_line "$trimmed" && continue
    _parse_spawn_fields "$trimmed"
    [[ "$(_spawn_key)" == "$want" ]] && return 0
  done < "$file"
  return 1
}

load_catalog() {
  local file="$1" line trimmed name path
  CATALOG_NAMES=()
  CATALOG_PATHS=()
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_line "$line")"
    [[ -z "$trimmed" || "$trimmed" != *"|"* ]] && continue
    name="$(_parse_entry_name "$trimmed")"
    path="$(_parse_entry_path "$trimmed")"
    [[ -z "$name" || -z "$path" ]] && continue
    CATALOG_NAMES+=("$name")
    CATALOG_PATHS+=("$path")
  done < "$file"
  [[ ${#CATALOG_NAMES[@]} -gt 0 ]]
}

list_catalog() {
  local file="${1:-$CATALOG}" line trimmed
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == \#* ]] && continue
    trimmed="$(trim_line "$line")"
    [[ -z "$trimmed" ]] && continue
    printf '  %s\n' "$line"
  done < "$file"
}

catalog_path() {
  local name="$1" file="$2" line trimmed n
  [[ -f "$file" ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_line "$line")"
    [[ -z "$trimmed" || "$trimmed" != *"|"* ]] && continue
    n="$(_parse_entry_name "$trimmed")"
    [[ "$n" == "$name" ]] && { _parse_entry_path "$trimmed"; return 0; }
  done < "$file"
  return 1
}

resolve_install_path() {
  local name="$1" catalog="$2" path root
  path="$(catalog_path "$name" "$catalog" 2>/dev/null || true)"
  if [[ -n "$path" ]]; then
    printf '%s' "$path"
    return 0
  fi
  root="${EDGE_ROOT:-~/Edge}"
  printf '%s' "$root"
}

add_catalog_entry() {
  local file="${1:?}" name="${2:?}" path="${3:?}" ts tmp found line trimmed
  ts="$(catalog_timestamp)"
  tmp="${file}.tmp"
  found=0
  touch "$file"
  _catalog_header "$file" "$tmp"
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_line "$line")"
    if [[ -n "$trimmed" && "$trimmed" == *"|"* && "$(_parse_entry_name "$trimmed")" == "$name" ]]; then
      printf '%s | %s  %s\n' "$ts" "$name" "$path" >> "$tmp"
      found=1
      continue
    fi
    [[ "$line" == \#* ]] && continue
    printf '%s\n' "$line" >> "$tmp"
  done < "$file"
  [[ $found -eq 0 ]] && printf '%s | %s  %s\n' "$ts" "$name" "$path" >> "$tmp"
  mv "$tmp" "$file"
}

remove_catalog_block() {
  local file="$1" drop="$2" tmp in_drop trimmed n line
  tmp="${file}.tmp"
  in_drop=0
  _catalog_header "$file" "$tmp"
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_line "$line")"
    if [[ -n "$trimmed" && "$trimmed" == *"|"* ]]; then
      n="$(_parse_entry_name "$trimmed")"
      if [[ "$n" == "$drop" ]]; then
        in_drop=1
        continue
      fi
      in_drop=0
    elif [[ $in_drop -eq 1 && -n "$trimmed" ]] && _is_spawn_line "$trimmed"; then
      continue
    elif [[ $in_drop -eq 1 && -z "$trimmed" ]]; then
      continue
    fi
    [[ "$line" == \#* ]] && continue
    printf '%s\n' "$line" >> "$tmp"
  done < "$file"
  mv "$tmp" "$file"
}

append_catalog_spawn() {
  local file="$1" script="$2" kind="$3" item="$4" extra="${5:-}" key tmp line trimmed n in_script
  key="${kind}|${item}|${extra}"
  _catalog_has_spawn "$file" "$key" && return 0
  tmp="${file}.tmp"
  in_script=0
  _catalog_header "$file" "$tmp"
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_line "$line")"
    if [[ -n "$trimmed" && "$trimmed" == *"|"* ]]; then
      n="$(_parse_entry_name "$trimmed")"
      if [[ $in_script -eq 1 ]]; then
        if [[ -n "$extra" ]]; then
          printf '> %s  %s  %s\n' "$kind" "$item" "$extra" >> "$tmp"
        else
          printf '> %s  %s\n' "$kind" "$item" >> "$tmp"
        fi
        in_script=0
      fi
      [[ "$n" == "$script" ]] && in_script=1
    fi
    [[ "$line" == \#* ]] && continue
    printf '%s\n' "$line" >> "$tmp"
  done < "$file"
  if [[ $in_script -eq 1 ]]; then
    if [[ -n "$extra" ]]; then
      printf '> %s  %s  %s\n' "$kind" "$item" "$extra" >> "$tmp"
    else
      printf '> %s  %s\n' "$kind" "$item" >> "$tmp"
    fi
  else
    return 1
  fi
  mv "$tmp" "$file"
}

collect_catalog_spawns() {
  local name="$1" file="$2"
  local line trimmed in_block
  in_block=0
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    trimmed="$(trim_line "$line")"
    if [[ -n "$trimmed" && "$trimmed" == *"|"* ]]; then
      if [[ "$(_parse_entry_name "$trimmed")" == "$name" ]]; then
        in_block=1
      else
        in_block=0
      fi
      continue
    fi
    [[ $in_block -eq 1 && -n "$trimmed" ]] || continue
    _is_spawn_line "$trimmed" || continue
    _parse_spawn_fields "$trimmed"
    printf '%s\t%s\t%s\n' "$SPAWN_KIND" "$SPAWN_ITEM" "${SPAWN_EXTRA:-}"
  done < "$file"
}
