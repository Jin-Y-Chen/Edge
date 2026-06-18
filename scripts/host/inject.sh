#!/usr/bin/env bash
# Usage: ./inject.sh <name>
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/function/helper.sh"
host_init "${BASH_SOURCE[0]}"

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && {
  echo "Usage: ./inject.sh <name>   # e.g. ./inject.sh connect_wifi"
  exit 0
}

[[ -n "${1:-}" ]] || {
  echo "Usage: ./inject.sh <name>" >&2
  echo "Edge scripts:" >&2
  list_edge_scripts >&2 || true
  load_catalog "$CATALOG" && { echo "In catalog:" >&2; list_catalog >&2; }
  exit 1
}

inject_script "$1"
