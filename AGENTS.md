# AGENTS.md

## 适用范围

- 本文件适用于整个仓库，只记录当前事实与稳定约束，不记录未来规划。
- 修改子目录前，先查找并阅读作用域内的 `AGENTS.md`；需要了解架构或用法时，再阅读最近的 `README.md`。局部约束不得放宽本文件的安全、敏感信息与 Git 规则。
- 架构细节由局部文档维护；实现与文档不一致时，以当前代码为调查起点，并同步修正相关文档。

## 项目导航

| 路径 | 作用 |
| --- | --- |
| `setup.sh` | 可远程执行的初始化入口，安装并运行 chezmoi |
| `install/` | 平台安装实现，由 `home/.chezmoiscripts/` 的模板引入 |
| `home/` | chezmoi source root，内容映射到 `$HOME` |
| `home/.chezmoiscripts/` | chezmoi 生命周期脚本 |
| `home/.chezmoitemplates/` | ignore、external 与脚本模板片段 |
| `home/dot_config/` | `~/.config` 下的应用配置 |
| `home/dot_zsh/` | Zsh 配置、插件管理与本地差异层 |
| `home/dot_local/bin/` | 部署到 `~/.local/bin` 的工具脚本 |
| `home/dot_agents/` | 多种 agent 共用的技能 |
| `home/dot_claude/`、`home/dot_codex/` | 产品专属的 agent 配置 |
| `home/private_*`、`home/**/encrypted_*` | 私有或加密的 chezmoi source state |
| `docker/`、`Makefile` | 隔离验证与仓库辅助入口 |

- 使用 `rg --files <目录>` 和 `rg <模式> <目录>` 导航，不在本文件维护完整文件树。
- 修改 Zsh Core 或通用工具前，分别阅读 [`home/dot_zsh/core/AGENTS.md`](home/dot_zsh/core/AGENTS.md) 与 [`home/dot_local/bin/common/AGENTS.md`](home/dot_local/bin/common/AGENTS.md)；架构与用法说明见各自的 `README.md`。

## Chezmoi 约束

- `.chezmoiroot` 必须保持为 `home`；只修改仓库中的 source state，不直接编辑已部署到 `$HOME` 的目标文件。
- 按 chezmoi 语义使用 `dot_`、`private_`、`encrypted_`、`executable_`、`symlink_` 与 `.tmpl`。
- 链接使用 `symlink_<名称>` 源文件记录相对目标，不在 source state 中创建普通符号链接。
- 模板只用于确有机器、系统或数据差异的内容，避免无必要模板化。
- 共享配置须考虑 macOS 与 Debian 系 Linux；平台专属逻辑放入对应目录或条件模板，并保持 `client` / `server` 分支语义。不宣称支持尚未实现的平台。

## 结构边界

- `setup.sh` 必须保持为 Bash 远程入口，不得依赖仓库已克隆或当前工作目录。
- `install/` 是平台安装实现；修改其 include 路径、入口或顺序时，同时检查对应的 `home/.chezmoiscripts/` 包装模板，不复制另一套安装逻辑。
- Zsh 加载顺序为 `.pre_profile → core → manager → features → local → .post_profile → zshrc.post`；保持 `core` 的阶段依赖与无插件边界。
- 修改通用 CLI agent 约束时，同步更新 `home/dot_claude/CLAUDE.user.md` 与 `home/dot_codex/AGENTS.user.md`；仅当用户明确限定特定 CLI 或明确无需同步时例外。
- `.pre_profile` 与 `.post_profile` 属于机器本地用户配置，不得加入仓库或由 agent 修改。

## 工具管理边界

- 新增或迁移 CLI 工具到 mise、Zinit 前，先检查 `install/`、mise 平台片段及 Zinit 配置，确认该工具是否已由其他机制安装。
- 同一平台与系统角色下，一个工具原则上只保留一个主要安装来源；确需重复时，必须注明用途与优先级。
- macOS 重点检查 Homebrew 安装列表；Linux 分别检查 apt 安装脚本以及 `client` / `server` 的 mise 配置。
- 从某个安装来源删除工具前，确认所有目标平台仍有可用的安装来源，避免迁移后缺失。

## 敏感信息

- 不解密、输出或复制现有密钥与凭据；未经明确要求，不修改 `.key.txt.age`、`private_*` 或 `encrypted_*`。
- 新增敏感内容必须使用 chezmoi 加密形式，禁止提交明文。
- Docker 验证不得使用真实私钥、令牌或个人配置。

## 验证

- 默认只做与改动匹配的静态验证，例如 shell 语法检查、`shellcheck`、模板渲染和 `chezmoi diff`。
- 不自动执行 `chezmoi apply`、`make init`、`make update`、`make reset`、`setup.sh` 或安装脚本。
- 需要动态验证时使用 `docker/` 提供的隔离环境；无法验证时明确说明缺口。

## Git 提交

- 修改前后检查 `git status`，只暂存当前任务文件，不带入已有或无关改动；一个提交只包含一个逻辑变更。
- 仅在用户明确要求时提交。仅为当前任务的最近提交使用 `--amend`；不自动 push、强推、rebase 或改写更早历史。
- 提交信息使用 `<type>(<scope>): <中文摘要>`；`type` 使用小写的 `feat`、`fix`、`chore`、`docs`、`refactor` 或 `test`，`scope` 使用实际子系统名。
- 示例：`feat(skill): 新增 IDA 无 MCP 反编译技能`；`chore(mise): 调整 Node 工具顺序`。避免 `update config` 等含糊摘要。
