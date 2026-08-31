#!/usr/bin/env bash

set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-bootstrap.XXXXXX")"
trap 'rm -rf "${test_root}"' EXIT

worktree="${test_root}/worktree"
bare_repo="${test_root}/dotfiles.git"
test_home="${test_root}/home"

mkdir -p "${worktree}" "${test_home}"

(
  cd "${repo_root}"
  tar -cf - .
) | (
  cd "${worktree}"
  tar -xf -
)

rm -rf "${worktree}/.git"

git -C "${worktree}" init -b main
git -C "${worktree}" config user.name "Dotfiles CI"
git -C "${worktree}" config user.email "dotfiles-ci@example.invalid"
git -C "${worktree}" add -A
git -C "${worktree}" commit -m "ci: bootstrap fixture"
git clone --bare "${worktree}" "${bare_repo}"

mkdir -p "${test_home}/.config/chezmoi"

cat > "${test_home}/.config/chezmoi/chezmoi.yaml" <<EOF_CONFIG
data:
  system: "server"
  use_secrets: false
  git:
    user_name: "Dotfiles CI"
    user_email: "dotfiles-ci@example.invalid"
EOF_CONFIG

export CI=true
export HOME="${test_home}"
unset ZDOTDIR || true

echo "==> Running setup.sh against the current checkout"

DOTFILES_REPO_URL="file://${bare_repo}" \
BRANCH_NAME="main" \
bash "${worktree}/setup.sh"

if [[ ! -e "${HOME}/.zshenv" ]]; then
  echo "Bootstrap completed but ~/.zshenv does not exist" >&2
  exit 1
fi

if [[ ! -d "${HOME}/.local/share/chezmoi" ]]; then
  echo "Bootstrap completed but chezmoi source directory does not exist" >&2
  exit 1
fi

actual_role="$(chezmoi execute-template '{{ .system }}')"

if [[ "${actual_role}" != "server" ]]; then
  echo "Unexpected bootstrap role: ${actual_role}" >&2
  exit 1
fi

env -u ZDOTDIR zsh -lc 'true'

echo "Bootstrap test passed."
