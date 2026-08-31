# syntax=docker/dockerfile:1.7

ARG UBUNTU_VERSION=22.04
FROM ubuntu:${UBUNTU_VERSION} AS base

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=chezmoi
ARG USER_UID=1000
ARG USER_GID=1000
ARG CHEZMOI_VERSION=2.72.0

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        coreutils \
        curl \
        findutils \
        fontconfig \
        git \
        make \
        python3 \
        shellcheck \
        sudo \
        xz-utils \
        zsh \
    && rm -rf /var/lib/apt/lists/*

COPY tests/ci/install-chezmoi.sh /usr/local/libexec/install-chezmoi-ci

RUN chmod 0755 /usr/local/libexec/install-chezmoi-ci \
    && /usr/local/libexec/install-chezmoi-ci "${CHEZMOI_VERSION}" /usr/local/bin \
    && chezmoi --version

# macOS 上常见的 GID 20 在 Ubuntu image 中可能已存在，因此复用已有 group。
RUN set -eux; \
    if getent group "${USER_GID}" >/dev/null 2>&1; then \
        primary_group="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    else \
        groupadd --gid "${USER_GID}" "${USERNAME}"; \
        primary_group="${USERNAME}"; \
    fi; \
    if getent passwd "${USER_UID}" >/dev/null 2>&1; then \
        existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
        if [ "${existing_user}" != "${USERNAME}" ]; then \
            usermod \
                --login "${USERNAME}" \
                --home "/home/${USERNAME}" \
                --move-home \
                "${existing_user}"; \
        fi; \
        usermod \
            --gid "${primary_group}" \
            --append \
            --groups sudo \
            --shell /bin/bash \
            "${USERNAME}"; \
    else \
        useradd \
            --uid "${USER_UID}" \
            --gid "${primary_group}" \
            --groups sudo \
            --create-home \
            --shell /bin/bash \
            "${USERNAME}"; \
    fi; \
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "${USERNAME}" > "/etc/sudoers.d/${USERNAME}"; \
    chmod 0440 "/etc/sudoers.d/${USERNAME}"; \
    mkdir -p "/home/${USERNAME}/.local/share/fonts"; \
    chown -R "${USER_UID}:${USER_GID}" "/home/${USERNAME}"

# -----------------------------------------------------------------------------
# Development image
# -----------------------------------------------------------------------------
FROM base AS dev

ARG USERNAME=chezmoi

USER ${USERNAME}
WORKDIR /home/${USERNAME}/.local/share/chezmoi

CMD ["/bin/bash", "--login"]

# -----------------------------------------------------------------------------
# Test image
# -----------------------------------------------------------------------------
FROM base AS test

ARG USERNAME=chezmoi
ARG USER_UID=1000
ARG USER_GID=1000

USER root

COPY --chown=${USER_UID}:${USER_GID} . /workspace/dotfiles

RUN chmod 0755 /workspace/dotfiles/tests/ci/*.sh

USER ${USERNAME}
WORKDIR /workspace/dotfiles

ENTRYPOINT ["/workspace/dotfiles/tests/ci/run.sh"]
CMD ["smoke"]
