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
    end
    A -->|软链接| B

    subgraph bootstrap["~/.zsh/.zshrc 加载的文件（从上到下）"]
        direction TB
        D["~/.pre_profile（若存在）"]
        E["~/.zsh/zshrc"]
        F["~/.post_profile（若存在）"]
    end
    C -->|1| D
    C -->|2| E
    C -->|3| F

    subgraph config["~/.zsh/zshrc 加载的文件（从上到下）"]
        direction TB
        G["~/.zsh/core/*"]
        H["~/.zsh/managers/*"]
        I["~/.zsh/features/*"]
        J["~/.zsh/local/override.zsh（若存在）"]
    end
    E -->|1| G
    E -->|2| H
    E -->|3| I
    E -->|4| J
```



...
