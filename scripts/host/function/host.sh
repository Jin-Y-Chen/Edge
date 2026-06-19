#!/usr/bin/env bash
# Host library — source from host/* scripts, then call host_init.

CATALOG_NAMES=()
CATALOG_PATHS=()
BOARD_ROUTE=""

_HOST_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=util.sh
source "${_HOST_LIB_DIR}/util.sh"
# shellcheck source=board.sh
source "${_HOST_LIB_DIR}/board.sh"
# shellcheck source=ssh.sh
source "${_HOST_LIB_DIR}/ssh.sh"
# shellcheck source=catalog.sh
source "${_HOST_LIB_DIR}/catalog.sh"
# shellcheck source=spawn.sh
source "${_HOST_LIB_DIR}/spawn.sh"
# shellcheck source=edge.sh
source "${_HOST_LIB_DIR}/edge.sh"
# shellcheck source=inject.sh
source "${_HOST_LIB_DIR}/inject.sh"
# shellcheck source=reject.sh
source "${_HOST_LIB_DIR}/reject.sh"

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
