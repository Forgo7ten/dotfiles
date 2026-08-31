DOCKER_IMAGE_NAME=dotfiles
DOCKER_ARCH=x86_64
DOCKER_NUM_CPU=4
DOCKER_RAM_GB=4

#
# Docker
#

.PHONY: docker
docker:
	docker build -f docker/Dockerfile --network host -t $(DOCKER_IMAGE_NAME) . --build-arg USERNAME="$$(whoami)"
	docker run --network host -it -v "$$(pwd):/home/$$(whoami)/.local/share/chezmoi" $(DOCKER_IMAGE_NAME) /bin/bash --login

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
