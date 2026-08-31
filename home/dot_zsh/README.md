# Zsh 配置目录

本目录对应部署后的 `~/.zsh/`，用于组织 Zsh 的启动文件、基础配置、插件管理器、交互功能和机器差异配置。入口文件 `~/.zshenv` 由目录外的 chezmoi 符号链接指向 `~/.zsh/.zshenv`。

## 一级文件

| 源文件 | 部署后的路径 | 作用 |
| --- | --- | --- |
| `dot_zshenv.tmpl` | `~/.zsh/.zshenv` | 由每次 Zsh 启动加载；设置 `ZDOTDIR`，并加载 `env.zsh`。 |
| `dot_zprofile` | `~/.zsh/.zprofile` | 登录 shell 的入口；系统登录初始化后重新加载 `path.zsh`，恢复统一的 PATH 顺序。 |
| `dot_zshrc` | `~/.zsh/.zshrc` | 交互式 shell 的启动引导；初始化补全路径，依次加载本机的 `.zshrc.pre`、`zshrc` 和 `.zshrc`。 |
| `env.zsh.tmpl` | `~/.zsh/env.zsh` | 所有 Zsh 会话共享的环境设置；定义 Android SDK 根目录并加载统一的 `path.zsh`，同时设置 uv 等变量。 |
| `path.zsh.tmpl` | `~/.zsh/path.zsh` | 通用 PATH 的主策略；可安全重复加载，维护用户工具、mise shims 和 Android SDK 路径。平台功能仍可追加专属路径。 |
| `zshrc.tmpl` | `~/.zsh/zshrc` | 交互式配置主编排器；按顺序加载 `core/`、选定的 `managers/`、`features/`，最后加载 `local/override.zsh`。 |

## 一级目录

| 目录 | 作用 |
| --- | --- |
| `core/` | 插件无关的基础配置，在插件管理器前加载；包含 Zsh 选项、键位和 manager 初始化前必须可见的运行时。详见 [`core/README.md`](core/README.md)。 |
| `managers/` | 插件管理器配置。`zshrc` 根据模板数据选择 `zinit`、`zimfw` 或禁用插件管理器；详见 [`managers/README.md`](managers/README.md)。 |
| `features/` | 插件管理器之后加载的交互功能、别名、函数、补全和平台工具集成。数字前缀决定阶段顺序。 |
| `local/` | 本机差异配置；由 `override.zsh.tmpl` 按操作系统和主机名加载 `common`、`os` 与 `host` 配置。 |

## 加载顺序

交互式 shell 的主要顺序为：

```text
~/.zsh/.zshrc
  → ~/.zshrc.pre（若存在）
  → ~/.zsh/zshrc
      → core/
      → managers/
      → features/
      → local/override.zsh（若存在）
  → ~/.zshrc（若存在）
```

`~/.zsh/.zshenv` 与 `~/.zsh/.zprofile` 由 Zsh 按 shell 类型分别加载，不属于上述交互式 `.zshrc` 链路；`.zshenv` 会先加载 `~/.zsh/env.zsh`，再由 `env.zsh` 加载统一的 `~/.zsh/path.zsh`；登录 shell 的 `.zprofile` 会在系统登录初始化后再次加载同一文件，以恢复用户 PATH 优先级，而不是维护第二份 PATH。
