# Zsh Core

`core/` 提供 Zsh 启动时最先加载的基础环境。它位于插件管理器之前，负责建立不依赖插件的最小配置，使后续插件、工具和机器差异层拥有稳定的运行基础。

## 加载方式

[`../zshrc.tmpl`](../zshrc.tmpl) 按目录和文件名顺序加载渲染后的 `core/**/*.zsh`。当前阶段为：

```text
00-bootstrap → 10-env → 20-options → 30-keymap
```

| 阶段 | 主要作用 |
| --- | --- |
| `00-bootstrap/` | 提供后续配置会使用的基础类型和轻量辅助函数 |
| `10-env/` | 设置环境变量与命令搜索路径 |
| `20-options/` | 配置 Zsh 行为和补全样式 |
| `30-keymap/` | 配置基础键位与 ZLE 行为 |

数字前缀决定加载先后；chezmoi 会将 `.zsh.tmpl` 渲染为目标端的 `.zsh` 文件。

## 与其他 Zsh 层的关系

完整的主配置加载流程为：

```text
core → managers → core.post → local
```

- `../managers/` 初始化 zinit 或 zimfw 等插件管理器。
- `../core.post/` 放置依赖插件或外部工具的环境、别名和函数。
- `../local/` 加载通用、操作系统及主机级差异配置。
- `../zshrc.post.zsh.tmpl` 在主配置和用户本地 profile 之后完成最终插件配置。

修改本目录时遵循同目录 [`AGENTS.md`](AGENTS.md) 中的分层和验证约束。
