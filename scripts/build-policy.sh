#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$repo_root/extension/clean-ui"
output_dir="$repo_root/dist"
output_oxt="$output_dir/portable-clean-libreoffice.oxt"

if ! command -v zip >/dev/null 2>&1; then
  echo "The zip command is required to build the policy extension." >&2
  exit 1
fi

if command -v xmllint >/dev/null 2>&1; then
  while IFS= read -r xml_file; do
    xmllint --noout "$xml_file"
  done < <(find "$source_dir" -type f \( -name '*.xml' -o -name '*.xcu' \) -print | LC_ALL=C sort)
fi

stage="$(mktemp -d "${TMPDIR:-/tmp}/libreoffice-clean-policy.XXXXXX")"
cleanup() {
  rm -rf "$stage"
}
trap cleanup EXIT

cp -R "$source_dir/." "$stage/"
find "$stage" -type f -exec touch -t 200001010000 {} +
mkdir -p "$output_dir"
rm -f "$output_oxt"

(
  cd "$stage"
  find . -type f -print | LC_ALL=C sort | zip -X -q "$output_oxt" -@
)

echo "Built: $output_oxt"
