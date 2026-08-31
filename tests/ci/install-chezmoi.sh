#!/usr/bin/env bash

set -Eeuo pipefail

version="${1:-2.72.0}"
bin_dir="${2:-${HOME}/.local/bin}"

case "$(uname -s)" in
  Linux) os="linux" ;;
  Darwin) os="darwin" ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *)
    echo "Unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

asset="chezmoi_${version}_${os}_${arch}.tar.gz"
checksums="chezmoi_${version}_checksums.txt"
base_url="https://github.com/twpayne/chezmoi/releases/download/v${version}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

archive_path="${tmp_dir}/${asset}"
checksums_path="${tmp_dir}/${checksums}"

curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 \
  "${base_url}/${asset}" -o "${archive_path}"
curl -fsSL --retry 3 --retry-all-errors --retry-delay 2 \
  "${base_url}/${checksums}" -o "${checksums_path}"

expected_sha="$(${AWK:-awk} -v asset="${asset}" '$2 == asset { print $1; exit }' "${checksums_path}")"

if [[ -z "${expected_sha}" ]]; then
  echo "Checksum entry not found for ${asset}" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  actual_sha="$(sha256sum "${archive_path}" | awk '{print $1}')"
elif command -v shasum >/dev/null 2>&1; then
  actual_sha="$(shasum -a 256 "${archive_path}" | awk '{print $1}')"
else
  echo "Neither sha256sum nor shasum is available" >&2
  exit 1
fi

if [[ "${actual_sha}" != "${expected_sha}" ]]; then
  echo "Checksum verification failed for ${asset}" >&2
  echo "expected: ${expected_sha}" >&2
  echo "actual:   ${actual_sha}" >&2
  exit 1
fi

tar -xzf "${archive_path}" -C "${tmp_dir}"

if [[ ! -x "${tmp_dir}/chezmoi" ]]; then
  echo "chezmoi binary not found in release archive" >&2
  exit 1
fi

mkdir -p "${bin_dir}"
install -m 0755 "${tmp_dir}/chezmoi" "${bin_dir}/chezmoi"

"${bin_dir}/chezmoi" --version
