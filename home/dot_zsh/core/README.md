# Zsh Core

`core/` 提供 Zsh 启动时最先加载的基础环境。它位于插件管理器之前，负责建立不依赖插件的最小配置，并在最后激活 manager 初始化所需的已安装运行时，使后续插件、工具和机器差异层拥有稳定的运行基础。

## 加载方式

[`../zshrc.tmpl`](../zshrc.tmpl) 按目录和文件名顺序加载渲染后的 `core/**/*.zsh`。当前阶段为：

```text
00-bootstrap → 10-env → 20-options → 30-keymap → 40-runtime
```

| 阶段 | 主要作用 |
| --- | --- |
| `00-bootstrap/` | 提供后续配置会使用的基础类型和轻量辅助函数 |
| `10-env/` | 设置环境变量与命令搜索路径 |
| `20-options/` | 配置 Zsh 行为和补全样式 |
| `30-keymap/` | 配置基础键位与 ZLE 行为 |
| `40-runtime/` | 激活插件管理器加载前必须可见的已安装运行时和工具路径 |

数字前缀决定加载先后；chezmoi 会将 `.zsh.tmpl` 渲染为目标端的 `.zsh` 文件。

`40-runtime/` 是 core 内部专用于 manager 前运行时激活的 seam。这里可以对已安装命令执行有保护的 shell 激活，但不得安装或更新工具、访问网络或写入持久状态。依赖插件或外部工具的普通环境、别名、函数与交互行为仍放在 `features/`。

## 与其他 Zsh 层的关系

完整的交互式 Zsh 启动流程为：

```text
~/.zshenv
  → ~/.zshrc: .pre_profile
  → ~/.zsh/zshrc: core → managers → features → local
  → ~/.zshrc: .post_profile
```

- `~/.zshenv` 在 Ubuntu 上设置 `skip_global_compinit=1`，阻止 `/etc/zsh/zshrc` 提前初始化补全；`compinit` 由所选插件管理器统一负责。
- `../managers/` 初始化 zinit 或 zimfw 等插件管理器，并集中声明插件、补全与延迟加载阶段；具体顺序见 [`../managers/README.md`](../managers/README.md)。
- `../features/` 放置依赖插件或外部工具的环境、别名和函数。
- `../local/` 加载通用、操作系统及主机级差异配置。
- `.pre_profile` 与 `.post_profile` 是机器本地覆盖层，分别位于主配置之前和之后，不由 chezmoi 管理。

Zinit 的 Turbo 插件会在 manager 阶段完成声明，但可能在主配置加载结束后才实际执行；需要在 source 时立即可用的能力不得依赖延迟插件。

修改本目录时遵循同目录 [`AGENTS.md`](AGENTS.md) 中的分层和验证约束。
