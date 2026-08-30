# Zsh Plugin Managers

`managers/` 由 [`../zshrc.tmpl`](../zshrc.tmpl) 在 `core` 之后、`features` 之前加载。所选 manager 负责初始化插件管理器，并集中声明插件、补全系统、主题与延迟加载阶段。

## Zinit 加载阶段

[`zinit.zsh`](zinit.zsh) 的主要阶段为：

| 阶段 | 内容 | 约束 |
| --- | --- | --- |
| 同步 | Zinit、所需 annex、OMZ libs、Powerlevel10k、direnv | manager 返回前必须可用，或不适合延迟的能力 |
| `0a` | OMZ plugins 与 `zsh-you-should-use` | 先提供 aliases 与 functions，再加载 ZLE 相关插件 |
| `0b` | `zsh-completions`、`compinit` 与 `compdef` replay | 收集同步 features 和 `0a` 插件的补全定义后统一初始化 |
| `0c` | fzf、fzf-tab、语法高亮、自动建议、历史搜索与 zoxide | 必须在 `compinit` 之后加载；内部顺序影响 ZLE widget 包装 |
| `1` / `1c` | thefuck、NVM、本地生成的工具补全 | 非首屏必需能力 |

Turbo 阶段在 manager 文件中完成声明，但可能在主配置加载结束后才执行。需要在 source 时立即可用的 features 不得依赖这些延迟插件。

## 补全与 ZLE 顺序

- Ubuntu 的 `~/.zsh/env.zsh` 设置 `skip_global_compinit=1`，该文件由 `~/.zsh/.zshenv` 加载，避免 `/etc/zsh/zshrc` 提前调用 `compinit`；Zinit 在 `0b` 阶段统一初始化补全。
- `compinit` 运行前的直接 `compdef` 必须由 Zinit 临时捕获，并在 `zicompinit` 后通过 `zicdreplay` 重放。
- `zsh-completions` 必须先于 `compinit` 准备好补全路径。
- fzf-tab 必须在 `compinit` 之后、会包装 ZLE widgets 的插件之前加载。
- 当前 ZLE 顺序固定为 `fzf --zsh → fzf-tab → fast-syntax-highlighting → zsh-autosuggestions → zsh-history-substring-search`。
- Powerlevel10k 保持同步加载，避免 Turbo 加载造成 prompt 二次刷新。
- direnv hook 在 manager 阶段同步安装；Powerlevel10k instant prompt 前的环境导入当前不启用，因为此时 Zinit 管理的 direnv 尚未加入 `PATH`。

`features` 在 manager 返回后、Turbo 阶段执行前加载，其中的自定义 `compdef` 由 Zinit 临时捕获；`0a` 的 OMZ 插件随后继续提交补全定义，最终由 `0b` 的 `zicompinit` 和 `zicdreplay` 一次性注册。`0c` 再加载 fzf 与 ZLE 插件，避免它们在补全系统初始化前接管 widgets。

## 二进制与 PATH

- `lbin` 由 `zinit-annex-binary-symlink` 提供，用于把下载的二进制链接到 Zinit 的统一 bin 目录。默认创建硬链接，因此 `ls -l` 会显示为普通文件；写成 `lbin"!name"` 才创建软链接。
- `pick"/dev/null"` 用于阻止 Zinit 自动选择并加载主文件，它本身不会把 `/dev` 加入 `PATH`。
- `as"program"` 会把插件目录或实际选中程序的目录加入 `PATH`。当前 direnv 与 zoxide 不使用 `as"program"`，而是通过 `lbin` 暴露二进制，并通过 `src` 加载各自生成的 Zsh hook。
- `lbin` 在插件 clone 或 pull hook 中创建链接。把已有配置从 `sbin` 改成 `lbin` 后，原有 shim 不会仅因启动新 shell 自动转换，需要重新安装或更新插件以触发相应 hook。

## 本地生成的工具补全

`local/completions` 只在首次 clone 或 Zinit update 时，为当前已经存在的命令生成补全。mise 后续安装新工具后，需要手动刷新：

```zsh
zi update local/completions
```

生成脚本会跳过不存在的命令，并以临时文件替换旧补全，避免生成失败时覆盖已有文件。

## 平台与命令条件

平台专属插件应在加入延迟列表前判断运行平台；依赖可选命令的插件应决定是按命令存在性加载，还是明确保留为外部软件预置。

| 插件或集成 | 外部命令或环境 | 缺失时的行为 |
| --- | --- | --- |
| `OMZP::git` | `git` | aliases 仍会注册，调用时失败 |
| `OMZP::gitignore` | `curl` 与 gitignore.io 网络连接 | 启动不受影响；调用 `gi` 或其补全时失败 |
| `OMZP::docker` | `docker` | 不会在启动时报错，但会留下不可用的 Docker aliases |
| `OMZP::docker-compose` | `docker-compose`，或支持 `docker compose` 的 `docker` | 两者都不存在时仍会留下不可用 aliases |
| `OMZP::ssh` | `grep`、`awk`、`sort`、`uniq`、`sed`；相关函数还需要 `ssh-keygen`、`ssh-add` | 读取 `~/.ssh/config` 生成主机补全；命令缺失时加载或调用相应函数可能失败 |
| `OMZL::clipboard.zsh` 与 copy plugins | `pbcopy`、`wl-copy`、`xclip`、`xsel` 或 tmux 等至少一种剪贴板后端 | 启动安全；调用复制命令时给出无可用后端错误 |
| `OMZP::extract` | 按压缩格式使用 `tar`、`unzip`、`unrar`/`unar`、`7za`、`xz`、`zstd` 等 | 启动安全；只影响对应格式的解压 |
| `OMZP::cp` | `rsync` | `cpv` 调用时失败 |
| `OMZP::command-not-found` | 发行版提供的 command-not-found handler 或数据库 | 未发现可用实现时为空载荷，不影响启动 |
| `OMZP::aliases` | `python3` | 仅 `als` 命令不可用，并在调用时输出提示 |
| `OMZP::bgnotify` | 本地交互式会话；桌面通知需要 `terminal-notifier`、`notify-send`、`kdialog` 等后端之一 | SSH 会话直接跳过；无通知后端时仍注册 hooks，并保留默认终端响铃 |
| `OMZP::systemd` | Linux 与 `systemctl` | 当前已按平台和命令过滤；非 systemd 的容器或 WSL 仍可能存在不可用 aliases |
| `OMZP::macos` | macOS 的 `defaults`、`osascript` 等系统命令 | 当前仅在 Darwin 加载 |
| `zsh-you-should-use` | `tput`；Git alias 检查还需要 `git` | 无 `tput` 时加载期输出警告并退回无颜色消息 |
| fzf shell integration 与 fzf-tab | 支持 `--zsh` 的较新 `fzf` | shell integration 会跳过；fzf-tab 当前仍会加载，按 Tab 时可能失败 |
| thefuck integration | `thefuck` | 当前有命令存在性检查，缺失时跳过 |
| NVM integration | `~/.nvm/nvm.sh` | 当前有文件存在性检查，缺失时跳过 |

新增或迁移工具时，还需按仓库根 [`AGENTS.md`](../../../AGENTS.md) 的工具管理边界检查 Homebrew、apt、mise 与 Zinit 是否重复管理。表中“启动安全”只表示 source 阶段不报错，不表示对应命令可用。
