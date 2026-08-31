#!/usr/bin/env bash

set -Eeuo pipefail

mode="${1:-smoke}"
role="${TEST_ROLE:-client}"

case "${mode}" in
  smoke|full) ;;
  *)
    echo "Usage: $0 {smoke|full}" >&2
    exit 2
    ;;
esac

case "${role}" in
  client|server) ;;
  *)
    echo "TEST_ROLE must be client or server" >&2
    exit 2
    ;;
esac

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-ci.XXXXXX")"
trap 'rm -rf "${test_root}"' EXIT

export CI=true
export HOME="${test_root}/home"
unset ZDOTDIR || true

source_dir="${HOME}/.local/share/chezmoi"
config_dir="${HOME}/.config/chezmoi"
config_file="${config_dir}/chezmoi.yaml"

mkdir -p "${source_dir}" "${config_dir}"

# 使用 tar pipe 复制当前 checkout，避免修改开发者的真实 HOME。
(
  cd "${repo_root}"
  tar -cf - .
) | (
  cd "${source_dir}"
  tar -xf -
)

# 为 PATH 测试准备确实存在的目录。
mkdir -p "${HOME}/.local/bin/common"
mkdir -p "${HOME}/.local/share/mise/shims"

# Smoke 排除 externals，但 client 的 Rime 用户配置仍需覆盖到 external 目标目录。
if [[ "${role}" == "client" ]]; then
  mkdir -p "${HOME}/.local/share/rime/oh-my-rime/dicts"
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
  mkdir -p "${HOME}/.local/bin/macos"
fi

cat > "${config_file}" <<EOF_CONFIG
data:
  system: "${role}"
  use_secrets: false
  git:
    user_name: "Dotfiles CI"
    user_email: "dotfiles-ci@example.invalid"
  tools:
    jeb_home: "${HOME}/.local/share/jeb"
    jadx_home: "${HOME}/.local/share/jadx"
    ida_home: "${HOME}/.local/share/ida"
    android_sdk_ndk_version: "27.0.12077973"
    android_sdk_buildtools_version: "30.0.3"
EOF_CONFIG

if [[ "${mode}" == "smoke" ]]; then
  exclude_types="scripts,externals,encrypted"
else
  exclude_types="encrypted"
fi

chezmoi_cmd=(
  chezmoi
  --config "${config_file}"
)

apply_cmd=(
  "${chezmoi_cmd[@]}"
  apply
  --no-tty
  --skip-secrets
  --exclude="${exclude_types}"
)

verify_cmd=(
  "${chezmoi_cmd[@]}"
  verify
  --skip-secrets
  --exclude="${exclude_types}"
)

echo "==> Environment"
echo "mode: ${mode}"
echo "role: ${role}"
echo "os:   $(uname -s)"
echo "home: ${HOME}"
echo

echo "==> First apply with --init"
"${apply_cmd[@]}" --init

actual_role="$("${chezmoi_cmd[@]}" execute-template '{{ .system }}')"
actual_manager="$("${chezmoi_cmd[@]}" execute-template '{{ .shell.zsh.manager }}')"
actual_secrets="$("${chezmoi_cmd[@]}" execute-template '{{ .use_secrets }}')"

[[ "${actual_role}" == "${role}" ]] || {
  echo "Role mismatch: expected=${role}, actual=${actual_role}" >&2
  exit 1
}

[[ "${actual_manager}" == "zinit" ]] || {
  echo "Unexpected Zsh manager: ${actual_manager}" >&2
  exit 1
}

[[ "${actual_secrets}" == "false" ]] || {
  echo "use_secrets must be false in CI" >&2
  exit 1
}

echo "==> Second apply"
"${apply_cmd[@]}"

echo "==> Verify target state"
"${verify_cmd[@]}"

echo "==> Validate rendered Zsh syntax"
while IFS= read -r -d '' file; do
  echo "  zsh -n ${file#${HOME}/}"
  zsh -n "${file}"
done < <(
  find "${HOME}/.zsh" -type f \
    \( -name '*.zsh' -o -name '.zshenv' -o -name '.zprofile' -o -name '.zshrc' \) \
    -print0
)

if [[ ! -e "${HOME}/.zshenv" ]]; then
  echo "${HOME}/.zshenv was not created" >&2
  exit 1
fi

echo "==> Non-login Zsh startup"
actual_zdotdir="$(env -u ZDOTDIR zsh -c 'print -r -- "${ZDOTDIR:-}"')"

[[ "${actual_zdotdir}" == "${HOME}/.zsh" ]] || {
  echo "Unexpected ZDOTDIR: ${actual_zdotdir}" >&2
  exit 1
}

env -u ZDOTDIR zsh -c 'true'

echo "==> Login Zsh startup"
env -u ZDOTDIR zsh -lc 'true'

path_output="$(env -u ZDOTDIR zsh -lc 'print -l -- $path')"

if ! printf '%s\n' "${path_output}" | grep -Fxq "${HOME}/.local/bin"; then
  echo "~/.local/bin is missing from login PATH" >&2
  printf '%s\n' "${path_output}" >&2
  exit 1
fi

local_bin_index="$(printf '%s\n' "${path_output}" | awk -v path="${HOME}/.local/bin" '$0 == path { print NR; exit }')"

for system_path in /usr/local/bin /usr/bin /bin; do
  system_path_index="$(printf '%s\n' "${path_output}" | awk -v path="${system_path}" '$0 == path { print NR; exit }')"
  [[ -n "${system_path_index}" ]] || continue

  if (( local_bin_index >= system_path_index )); then
    echo "~/.local/bin must precede ${system_path}" >&2
    printf '%s\n' "${path_output}" >&2
    exit 1
  fi
done

duplicate_paths="$({
  printf '%s\n' "${path_output}" |
    awk 'NF { count[$0]++ } END { for (p in count) if (count[p] > 1) print p }'
} || true)"

if [[ -n "${duplicate_paths}" ]]; then
  echo "Duplicate PATH entries found:" >&2
  printf '%s\n' "${duplicate_paths}" >&2
  exit 1
fi

echo
echo "Chezmoi ${mode} test passed for role=${role}."
