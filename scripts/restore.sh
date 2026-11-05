#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "${1:-}" in
  ""|--merge) exec python3 "$repo_root/scripts/lo-settings.py" apply ;;
  --replace) exec python3 "$repo_root/scripts/lo-settings.py" apply --replace ;;
  *) echo "Usage: $0 [--merge|--replace]" >&2; exit 2 ;;
esac
