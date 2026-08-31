#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command="${1:-smoke}"

case "${command}" in
  static)
    exec "${script_dir}/static.sh"
    ;;
  smoke)
    exec "${script_dir}/chezmoi-smoke.sh" smoke
    ;;
  full)
    exec "${script_dir}/chezmoi-smoke.sh" full
    ;;
  bootstrap)
    exec "${script_dir}/bootstrap.sh"
    ;;
  *)
    echo "Usage: $0 {static|smoke|full|bootstrap}" >&2
    exit 2
    ;;
esac
