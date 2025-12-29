# Dotfiles Code Agent 指令式规范

## （ChezMoi + Zsh + Cross-Platform Install）

>   ⚠️ **本文件是仓库的“宪法级定义”**
>   本文档中的结构、职责与约束 **具有强制性**。
>   任何 code agent、脚本、配置调整 **不得违背或弱化本规范**。

------

## 0. 设计目标（Design Goals）

-   dotfiles **可重复部署**
-   shell 架构 **清晰、可推理**
-   install **零前置依赖**
-   用户私有边界 **不可侵犯**
-   **Linux / macOS 同等一等公民**
-   **一行命令即可完成初始化**

------

## 1. 仓库模型（Repository Model）

-   本仓库使用 **chezmoi** 管理 dotfiles
-   `home/` 是 **chezmoi 的 source root**
-   `home/` 下的所有内容将映射到 `$HOME`
-   仓库根目录文件 **不会** 被 apply 到 `$HOME`

### 1.1 语义说明

-   `.chezmoiroot` 文件存在，且其内容为 `home`
-   任何 **不在 `home/` 下的文件**
    -   ❌ 不属于 `$HOME` 的最终状态
    -   ❌ 不受 chezmoi apply 影响

### 1.2 强制约束

-   ❌ 不允许将真实配置文件放在仓库根目录
-   ❌ 不允许 code agent 修改 `.chezmoiroot`
-   ❌ 不允许通过符号链接绕过 `home/`

------

## 2. Setup / Install 结构（环境引导层）🆕

>   **setup = 远程可执行引导器**
>   **install = 本地平台实现**
>   **dotfiles = 最终用户状态**

------

### 2.1 权威目录结构

```
.
├── setup.sh                 # ✅ 远程可 curl | bash 的唯一入口
├── home/                     # chezmoi source root
├── install/                  # 🆕 平台相关安装脚本（用户手动调用）
│   ├── common/           # 跨平台通用逻辑
│   ├── macos/
│   │   └── run.sh
│   └── ubuntu/
│       └── run.sh
├── example/                  # 🆕 参考示例（dotfiles1, dotfiles2）
└── tests/                    # 🆕 自动化测试（预留）
```

------

## 3. `setup.sh`（根目录，唯一入口）⚠️

### 3.1 核心定位（强制）

`setup.sh` **必须支持如下用法**：

```
bash -c "$(curl -fsLS https://example.com/dotfiles/setup.sh)"
```

并且做到：

-   ✅ **无需 chezmoi 预安装**
-   ✅ **无需 git 预安装**
-   ✅ **无需 shell 配置存在**
-   ✅ 可在最小系统上执行

------

### 3.2 `setup.sh` 的职责边界

`setup.sh` 必须且只能负责：

1.  打印 `DOTFILES_LOGO`
2.  定义 `main()` 作为唯一入口
3.  OS / ARCH 探测
4.  `initialize_os_env`
5.  **安装 chezmoi（若不存在）**
6.  **通过 chezmoi 初始化 dotfiles**

------

### 3.3 `setup.sh` 的强制约束

-   ❌ 不允许依赖本地仓库已 clone
-   ❌ 不允许假设当前工作目录
-   ❌ 不允许 source zsh / bash 配置
-   ❌ 不允许写入真实配置文件
-   ❌ 不允许使用 zsh-only 语法
-   ✅ 必须 POSIX shell 兼容
-   ✅ 脚本末尾 **只允许执行 `main`**

------

## 4. `install/**`（平台实现层）

### 4.1 职责定义

install 层脚本由 **用户手动调用**，仅负责：

-   系统级依赖安装（如 direnv, zoxide, 字体等）
-   包管理器操作（brew, apt 等）

install 层 **永远不关心 dotfiles 内容**。

------

### 4.2 install 层禁止行为

-   ❌ 写入 `$HOME/.zsh*`
-   ❌ source 任何 shell 配置
-   ❌ 运行 chezmoi apply
-   ❌ 修改用户环境状态

------

## 5. 跨平台命令规范（⚠️ 宪法级）🆕

### 5.1 基本原则

-   所有脚本 **必须同时支持**：
    -   Linux (ubuntu)
    -   macOS（Intel / Apple Silicon）
-   所有安装逻辑必须：
    -   **能力检测优先**
    -   **OS 判断兜底**

------

### 5.2 包管理器调用规范

✅ 正确：

```
if command -v brew >/dev/null 2>&1; then
  brew install direnv
elif command -v apt >/dev/null 2>&1; then
  sudo apt install -y direnv
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y direnv
fi
```

❌ 错误：

```
brew install direnv
apt install direnv
```

------

### 5.3 Shell 兼容性

-   所有 `install/**` / `setup.sh` 脚本：
    -   ❌ 不允许 zsh-only 语法
    -   ❌ 不允许 `$ZDOTDIR`
    -   ❌ 不允许依赖用户 shell 类型

------

## 6. Zsh 架构（保持不变，权威）

### 6.1 目录结构与职责

```text
├── dot_gradle/
│   └── init.gradle          # Gradle 全局初始化配置
├── dot_pip/
│   └── pip.conf             # Python pip 镜像源配置
├── dot_zimrc                # zimfw 模块配置文件
├── dot_zsh/                 # Zsh 配置根目录 ($ZDOTDIR)
│   ├── core/                # 核心配置层（无插件依赖，按顺序加载）
│   │   ├── 00-bootstrap/    # Shell 基础语义
│   │   ├── 10-env/          # 环境变量 (env.zsh.tmpl)
│   │   ├── 20-options/      # Zsh 行为选项 (options.zsh)
│   │   ├── 30-keymap/       # 键位映射 (keybindings.zsh)
│   │   └── 40-behavior/     # 用户行为 (aliases.zsh, functions.zsh)
│   ├── dot_p10k.zsh         # Powerlevel10k 主题配置
│   ├── local/               # 本地覆盖层
│   │   ├── common.zsh       # 通用本地配置
│   │   ├── os/              # OS 差异配置 (macos.zsh, linux.zsh)
│   │   ├── host/            # 机器差异配置 (work-laptop.zsh, etc.)
│   │   └── override.zsh.tmpl # 调度入口（chezmoi 模板，负责条件加载）
│   ├── managers/            # 插件管理器适配层
│   │   ├── zimfw.zsh        # zimfw 初始化逻辑
│   │   └── zinit.zsh        # zinit 初始化与插件加载逻辑
│   ├── zprofile             # 登录 Shell 配置
│   ├── zshrc                # 核心入口：调度 core -> managers -> local
│   └── zshrc_final          # 最终收尾：加载高亮/补全等需最后执行的插件
└── dot_zshrc                # Bootstrap 入口：设置 ZDOTDIR 并加载 pre/post profile、zshrc_final
```

### 6.2 加载流程

1.  `~/.zshrc` (Bootstrap)
    *   加载 `~/.pre_profile` (用户私有，最先)
    *   设置 `ZDOTDIR`
    *   加载 `~/.zsh/zshrc`
2.  `~/.zsh/zshrc` (Core Logic)
    *   递归加载 `core/**/*.zsh` (按字典序)
    *   加载 `managers/{zinit,zimfw}.zsh`
    *   加载 `local/override.zsh`
3.  `~/.zshrc` (Bootstrap 继续)
    *   加载 `~/.post_profile` (用户私有，插件后)
    *   加载 `~/.zsh/zshrc_final` (最终收尾)

------

## 7. 模板（.tmpl）使用规范

-   仅用于：
    -   OS
    -   Hostname
    -   chezmoi data
-   禁止用于：
    -   setup.sh
    -   `install/**` 脚本
    -   插件管理器
    -   shell 可判断逻辑

------

## 8. 明确禁止的行为（DO NOT）

-   ❌ setup.sh 写 dotfiles
-   ❌ setup.sh source zsh
-   ❌ install 层运行 chezmoi apply
-   ❌ install 层假设操作系统
-   ❌ install 层修改用户配置
-   ❌ code agent 修改用户私有 profile (pre_profile / post_profile)

------

## 9. 设计核心总结（最终权威）

-   `./setup.sh`
    → **远程可执行的一次性引导器**
-   `install/**`
    → **跨平台系统准备层（用户手动调用）**
-   `home/`
    → **chezmoi 唯一真实配置源**
-   `.pre_profile / .post_profile`
    → **用户主权边界**

>   **setup ≠ dotfiles
>   install ≠ shell config
>   dotfiles ≠ system provisioning**

------

## 10. 一句话定义（终极）

>   **这一仓库可以在任何一台干净的 Linux / macOS 机器上，
>   通过一行命令，
>   可重复、可推理、可维护地重建完整开发环境。**