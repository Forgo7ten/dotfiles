FROM ubuntu:22.04

ARG USERNAME=chezmoi
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

RUN sed -i "s@http://.*archive.ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list &&  \
    sed -i "s@http://.*security.ubuntu.com@http://mirrors.tuna.tsinghua.edu.cn@g" /etc/apt/sources.list

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git curl sudo \
    xz-utils fontconfig ca-certificates
    # && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -G sudo -s /bin/bash \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER ${USERNAME}

WORKDIR /home/$USERNAME/.local/share/chezmoi

# 提前下载 bin/chezmoi
COPY bin .
RUN sudo mv chezmoi /usr/local/bin/
# RUN sudo sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin


RUN mkdir -p ~/.local/share/fonts

CMD ["/bin/bash"]