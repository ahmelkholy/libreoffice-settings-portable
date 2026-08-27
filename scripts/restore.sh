#!/usr/bin/env bash
set -euo pipefail

mode="replace"
case "${1:-}" in
  ""|--replace)
    ;;
  --merge)
    mode="merge"
    ;;
  *)
    echo "Usage: $0 [--replace|--merge]" >&2
    exit 2
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_xcu="$repo_root/settings/registrymodifications.portable.xcu"
policy_oxt="$repo_root/dist/portable-clean-libreoffice.oxt"

if [[ ! -f "$source_xcu" ]]; then
  echo "Portable settings file not found: $source_xcu" >&2
  exit 1
fi

if [[ ! -f "$policy_oxt" ]]; then
  echo "Clean-interface policy extension not found: $policy_oxt" >&2
  exit 1
fi

find_unopkg() {
  local candidate
  local candidates=()

  if [[ -n "${LIBREOFFICE_UNOPKG:-}" ]]; then
    candidates+=("$LIBREOFFICE_UNOPKG")
  fi

  if command -v unopkg >/dev/null 2>&1; then
    candidates+=("$(command -v unopkg)")
  fi

  case "$(uname -s)" in
    Darwin)
      candidates+=(
        "/Applications/LibreOffice.app/Contents/MacOS/unopkg"
        "$HOME/Applications/LibreOffice.app/Contents/MacOS/unopkg"
      )
      ;;
    Linux)
      candidates+=(
        "/usr/lib/libreoffice/program/unopkg"
        "/usr/lib64/libreoffice/program/unopkg"
        "/opt/libreoffice/program/unopkg"
      )
      ;;
  esac

  for candidate in "${candidates[@]}"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if pgrep -x soffice >/dev/null 2>&1 ||
   pgrep -x soffice.bin >/dev/null 2>&1 ||
   pgrep -x libreoffice >/dev/null 2>&1; then
  echo "Close LibreOffice before restoring settings." >&2
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    profile="$HOME/Library/Application Support/LibreOffice/4/user"
    ;;
  Linux)
    profile="${XDG_CONFIG_HOME:-$HOME/.config}/libreoffice/4/user"
    ;;
  *)
    echo "Unsupported OS for this shell script. Use scripts/restore.ps1 if PowerShell is available." >&2
    exit 1
    ;;
esac

mkdir -p "$profile"
target="$profile/registrymodifications.xcu"
timestamp="$(date +%Y%m%d-%H%M%S)"

if [[ -f "$target" ]]; then
  cp "$target" "$target.restore-backup-$timestamp"
  echo "Backup: $target.restore-backup-$timestamp"
fi

if ! unopkg_path="$(find_unopkg)"; then
  echo "LibreOffice's unopkg tool was not found. Set LIBREOFFICE_UNOPKG to its full path." >&2
  exit 1
fi

"$unopkg_path" add --force --suppress-license "$policy_oxt"
if ! "$unopkg_path" validate org.ahmelkholy.libreoffice.cleanui; then
  echo "The clean-interface policy extension did not register correctly." >&2
  exit 1
fi
echo "Installed immutable clean-interface policy."

if [[ "$mode" == "replace" || ! -f "$target" ]]; then
  cp "$source_xcu" "$target"
  echo "Replaced LibreOffice settings: $target"
else
  python3 - "$source_xcu" "$target" <<'PY'
import copy
import sys
import xml.etree.ElementTree as ET

source, target = sys.argv[1], sys.argv[2]
OOR = "http://openoffice.org/2001/registry"
XS = "http://www.w3.org/2001/XMLSchema"
XSI = "http://www.w3.org/2001/XMLSchema-instance"

ET.register_namespace("oor", OOR)
ET.register_namespace("xs", XS)
ET.register_namespace("xsi", XSI)

src_tree = ET.parse(source)
dst_tree = ET.parse(target)
src_root = src_tree.getroot()
dst_root = dst_tree.getroot()

def xcu_attr(element, name):
    return element.attrib.get(f"{{{OOR}}}{name}", "")

def item_key(item):
    children = tuple(
        (child.tag.rsplit("}", 1)[-1], xcu_attr(child, "name"))
        for child in list(item)
    )
    return (xcu_attr(item, "path"), children)

portable_items = list(src_root)
portable_keys = {item_key(item) for item in portable_items}

for item in list(dst_root):
    if item_key(item) in portable_keys:
        dst_root.remove(item)

for item in portable_items:
    dst_root.append(copy.deepcopy(item))

dst_tree.write(target, encoding="UTF-8", xml_declaration=True)
PY
  echo "Merged portable settings into: $target"
fi

echo "Done. Start LibreOffice to load the restored settings."
