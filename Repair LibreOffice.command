#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
python3 scripts/lo-settings.py repair-macos
printf '\nRepair complete. Open your document normally.\n'
