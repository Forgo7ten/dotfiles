# Neovim 配置

本目录对应部署后的 `~/.config/nvim/`，使用 LazyVim 作为配置基础，由 `lazy.nvim` 负责插件加载与管理。

## 配置结构

| 路径 | 作用 |
| --- | --- |
| `init.lua` | Neovim 入口，仅加载 `config.lazy`。 |
| `lua/config/` | 编辑器选项、快捷键、自动命令和 `lazy.nvim` 启动配置，详见下文。 |
| `lua/plugins/` | 自定义插件声明与配置；每个文件返回 `lazy.nvim` plugin spec，详见下文。 |
| `lazyvim.json` | LazyVim extras 清单，例如语言、格式化和工具集成。 |
| `lazy-lock.json` | 锁定插件分支与 commit，保证插件版本可复现。 |
| `stylua.toml` | Lua 格式化规则。 |

## `lua/config/`

| 文件 | 作用 |
| --- | --- |
| `autocmds.lua` | 预留自定义自动命令入口；当前未添加额外自动命令。 |
| `keymaps.lua` | 定义自定义快捷键：终端模式和插入模式均可使用 `jj` 返回 Normal 模式。 |
| `lazy.lua` | 引导安装并加载 `lazy.nvim`，注册 LazyVim 与本地 `plugins/`，设置插件加载、更新检查和禁用的内置插件。 |
| `options.lua` | 预留自定义编辑器选项入口；当前使用 LazyVim 默认选项。 |

## `lua/plugins/`

| 文件 | 作用 |
| --- | --- |
| `blink-cmp.lua` | 配置 `blink.cmp` 使用 `super-tab` 键位预设；Tab 处理补全、Snippet 和回退，Shift-Tab 反向跳转。 |
| `chezmoi.lua` | 预留 `chezmoi.nvim` 配置；当前插件配置全部注释，实际返回空列表。 |
| `snacks.lua` | 配置 `snacks.nvim`：文件浏览器显示隐藏及被忽略文件，并定制启动 dashboard、最近文件、项目和 Git 状态区域。 |

## 当前自定义配置

插件文件由 `lazy.nvim` 自动发现并加载，不应在 `init.lua` 中逐个手动 `require`。

插件安装、更新和锁定文件维护由 `lazy.nvim` 完成；主动更新插件版本时，再提交相应的 `lazy-lock.json` 变化。
