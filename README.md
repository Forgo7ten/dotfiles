# 🛠️ Forgo7ten's Dotfiles

这是我的个人 Dotfiles 仓库，基于 **chezmoi** 管理。

## 📥 快速安装

只需运行以下命令即可自动初始化环境。该脚本将安装必要的依赖并应用配置文件。

-    方式 1: 使用 curl

```bash
bash -c "$(curl -fsLS https://raw.githubusercontent.com/Forgo7ten/dotfiles/main/setup.sh)"
```

-    方式 2: 使用 wget

```bash
bash -c "$(wget -qO - https://raw.githubusercontent.com/Forgo7ten/dotfiles/main/setup.sh)"
```

## CI 与本地验证

日常提交前使用 Docker 运行静态检查及 Ubuntu 22.04 的 client/server smoke：

```bash
make test
```

完整 Linux smoke matrix、单个 role、完整 provisioning 与 bootstrap 分别使用：

```bash
make test-all
make test-role TEST_ROLE=server
make test-full TEST_ROLE=server
make test-bootstrap
```

Docker 构建和容器会转发宿主机已设置的标准 HTTP/HTTPS 代理变量。`test-full` 与 `test-bootstrap` 会在一次性容器中执行安装脚本及 externals；日常 `make test` 不会执行这些副作用步骤。

本地 Linux 构建会自动将当前用户的 UID/GID 传入 Docker，以兼容 bind mount；GitHub Actions 与其他平台使用 Dockerfile 的默认 UID/GID。

macOS 的 Darwin 模板、`/etc/zprofile` 与 `path_helper` 只能在真实 macOS 环境中验证：

```bash
make test-native-macos
```

## Zsh 加载顺序

部署后，Zsh 从 `~/.zshenv` 开始，按以下真实文件顺序加载：

```mermaid
flowchart LR
    A["入口：~/.zshenv"]

    subgraph system["Zsh 按 shell 类型分别加载"]
        direction TB

        B["~/.zsh/.zshenv"]
        P["~/.zsh/.zprofile"]
        C["~/.zsh/.zshrc"]

        B ~~~ P
        P ~~~ C
    end

    subgraph environment["~/.zsh/.zshenv 加载的文件"]
        direction LR

        Q["~/.zsh/env.zsh"]
        R["~/.zsh/path.zsh（通用 PATH 主策略）"]

        Q --> R
    end

    subgraph bootstrap["~/.zsh/.zshrc 加载的文件（从上到下）"]
        direction TB

        D["~/.zshrc.pre（若存在）"]
        E["~/.zsh/zshrc"]
        F["~/.zshrc（若存在）"]

        D ~~~ E
        E ~~~ F
    end

    subgraph config["~/.zsh/zshrc 加载的文件（从上到下）"]
        direction TB

        G["~/.zsh/core/*"]
        H["~/.zsh/managers/*"]
        I["~/.zsh/features/*"]
        J["~/.zsh/local/override.zsh（若存在）"]

        G ~~~ H
        H ~~~ I
        I ~~~ J
    end

    A -->|软链接| system
    system -->|"由 .zshenv 加载"| environment
    system -->|"由 .zshrc 加载"| bootstrap
    bootstrap -->|"由 ~/.zsh/zshrc 加载"| config
```

`~/.zsh/path.zsh` 负责通用 PATH 的基础策略。`.zshenv` 链路负责让所有 shell 获得基础 PATH；登录 shell 会先执行系统级 zprofile，再由 `~/.zsh/.zprofile` 加载同一文件，用于恢复用户 PATH 优先级。平台功能仍可在各自 feature 文件中追加专属路径。



...
