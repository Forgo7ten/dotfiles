DOCKER_IMAGE_NAME ?= dotfiles
DOCKER_TEST_IMAGE_NAME ?= dotfiles-test

UBUNTU_VERSION ?= 22.04
CHEZMOI_VERSION ?= 2.72.0

DOCKER_USERNAME ?= $(shell whoami)

TEST_ROLE ?= client
TEST_ROLES ?= client server

# 本地 Linux 的 bind mount 需要匹配宿主机 UID/GID；GitHub Actions 和其他
# 平台保留 Dockerfile 中的默认值，避免把 runner 或 macOS 的身份写入镜像。
DOCKER_USER_ID_BUILD_ARGS =
ifneq ($(GITHUB_ACTIONS),true)
ifeq ($(shell uname -s),Linux)
DOCKER_USER_UID ?= $(shell id -u)
DOCKER_USER_GID ?= $(shell id -g)
DOCKER_USER_ID_BUILD_ARGS = \
	--build-arg USER_UID="$(DOCKER_USER_UID)" \
	--build-arg USER_GID="$(DOCKER_USER_GID)"
endif
endif

# BuildKit 的预定义代理参数使用大写名称；兼容仅设置小写变量的本地环境。
HTTP_PROXY := $(or $(HTTP_PROXY),$(http_proxy))
HTTPS_PROXY := $(or $(HTTPS_PROXY),$(https_proxy))
ALL_PROXY := $(or $(ALL_PROXY),$(all_proxy))
NO_PROXY := $(or $(NO_PROXY),$(no_proxy))
export HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY

DOCKER_TEST_TAG = $(DOCKER_TEST_IMAGE_NAME):ubuntu-$(UBUNTU_VERSION)
DOCKER_DEV_TAG = $(DOCKER_IMAGE_NAME):ubuntu-$(UBUNTU_VERSION)

# 仅转发宿主机已设置的标准代理变量，不把代理地址写入仓库或镜像层。
DOCKER_PROXY_BUILD_ARGS = \
	--build-arg HTTP_PROXY="$(HTTP_PROXY)" \
	--build-arg HTTPS_PROXY="$(HTTPS_PROXY)" \
	--build-arg ALL_PROXY="$(ALL_PROXY)" \
	--build-arg NO_PROXY="$(NO_PROXY)"

DOCKER_PROXY_RUN_ARGS = \
	--env HTTP_PROXY \
	--env HTTPS_PROXY \
	--env ALL_PROXY \
	--env NO_PROXY \
	--env http_proxy \
	--env https_proxy \
	--env all_proxy \
	--env no_proxy

#
# Docker
#

.PHONY: docker
docker:
	@docker build \
		-f docker/Dockerfile \
		--target dev \
		--build-arg UBUNTU_VERSION="$(UBUNTU_VERSION)" \
		--build-arg CHEZMOI_VERSION="$(CHEZMOI_VERSION)" \
		--build-arg USERNAME="$(DOCKER_USERNAME)" \
		$(DOCKER_USER_ID_BUILD_ARGS) \
		$(DOCKER_PROXY_BUILD_ARGS) \
		-t "$(DOCKER_DEV_TAG)" \
		.
	docker run --rm -it \
		$(DOCKER_PROXY_RUN_ARGS) \
		-v "$(CURDIR):/home/$(DOCKER_USERNAME)/.local/share/chezmoi" \
		"$(DOCKER_DEV_TAG)" \
		/bin/bash --login

.PHONY: test-build
test-build:
	@docker build \
		-f docker/Dockerfile \
		--target test \
		--build-arg UBUNTU_VERSION="$(UBUNTU_VERSION)" \
		--build-arg CHEZMOI_VERSION="$(CHEZMOI_VERSION)" \
		$(DOCKER_USER_ID_BUILD_ARGS) \
		$(DOCKER_PROXY_BUILD_ARGS) \
		-t "$(DOCKER_TEST_TAG)" \
		.

.PHONY: test-static
test-static: test-build
	docker run --rm $(DOCKER_PROXY_RUN_ARGS) "$(DOCKER_TEST_TAG)" static

.PHONY: test-role
test-role: test-build
	docker run --rm \
		$(DOCKER_PROXY_RUN_ARGS) \
		-e TEST_ROLE="$(TEST_ROLE)" \
		"$(DOCKER_TEST_TAG)" \
		smoke

.PHONY: test
test: test-build
	docker run --rm $(DOCKER_PROXY_RUN_ARGS) "$(DOCKER_TEST_TAG)" static
	@set -e; \
	for role in $(TEST_ROLES); do \
		echo "==> Ubuntu $(UBUNTU_VERSION) / role=$$role"; \
		docker run --rm \
			$(DOCKER_PROXY_RUN_ARGS) \
			-e TEST_ROLE="$$role" \
			"$(DOCKER_TEST_TAG)" \
			smoke; \
	done

.PHONY: test-all
test-all:
	$(MAKE) test UBUNTU_VERSION=22.04
	$(MAKE) test UBUNTU_VERSION=24.04

.PHONY: test-full
test-full: test-build
	docker run --rm \
		$(DOCKER_PROXY_RUN_ARGS) \
		-e TEST_ROLE="$(TEST_ROLE)" \
		"$(DOCKER_TEST_TAG)" \
		full

.PHONY: test-full-all
test-full-all: test-build
	@set -e; \
	for role in $(TEST_ROLES); do \
		echo "==> Full provisioning / role=$$role"; \
		docker run --rm \
			$(DOCKER_PROXY_RUN_ARGS) \
			-e TEST_ROLE="$$role" \
			"$(DOCKER_TEST_TAG)" \
			full; \
	done

.PHONY: test-bootstrap
test-bootstrap: test-build
	docker run --rm $(DOCKER_PROXY_RUN_ARGS) "$(DOCKER_TEST_TAG)" bootstrap

# 在真实 macOS 上测试 Darwin/path_helper 分支。
# chezmoi 被安装到临时目录，不污染用户已有 chezmoi。
.PHONY: test-native-macos
test-native-macos:
	@tmp="$$(mktemp -d)"; \
	trap 'rm -rf "$$tmp"' 0; \
	bash tests/ci/install-chezmoi.sh "$(CHEZMOI_VERSION)" "$$tmp"; \
	PATH="$$tmp:$$PATH" TEST_ROLE=client \
		bash tests/ci/chezmoi-smoke.sh smoke

#
# Chezmoi
#

.PHONY: init
init:
	chezmoi init --apply --verbose
	chezmoi-private init --apply --verbose --ssh Forgo7ten/dotfiles-private

.PHONY: update
update:
	chezmoi apply --verbose
	chezmoi-private apply --verbose

.PHONY: watch
watch:
	DOTFILES_DEBUG=1 watchexec -- chezmoi apply --verbose

.PHONY: reset
reset:
	chezmoi state delete-bucket --bucket=scriptState
	chezmoi state delete-bucket --bucket=entryState

.PHONY: reset-config
reset-config:
	chezmoi init --data=false
