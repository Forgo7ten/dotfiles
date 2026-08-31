#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

files=()

if [[ -f setup.sh ]]; then
  files+=(setup.sh)
fi

for dir in install scripts tests/ci; do
  [[ -d "${dir}" ]] || continue

  while IFS= read -r -d '' file; do
    files+=("${file}")
  done < <(find "${dir}" -type f -name '*.sh' -print0)
done

if (( ${#files[@]} == 0 )); then
  echo "No Bash files found"
  exit 0
fi

echo "==> bash -n"
for file in "${files[@]}"; do
  echo "  ${file}"
  bash -n "${file}"
done

echo "==> shellcheck"
shellcheck -S error "${files[@]}"

echo "Static checks passed."
