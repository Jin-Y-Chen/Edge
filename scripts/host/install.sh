#!/usr/bin/env bash
# Usage: ./install.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for f in "$DIR"/*.sh; do
  [[ -f "$f" ]] && chmod +x "$f" && echo "chmod +x host/$(basename "$f")"
done
echo "Done."
