# bin

## jadx-remote

需要配置.env

```bash
export JADX_REMOTE_HOST=user@host
```

## jeb-remote

需要配置.env

```bash
export JEB_REMOTE_HOST=user@host
export JEB_REMOTE_JEB_HOME=/path/to/JEB
export JEB_REMOTE_JEB_FRONTEND_JAR=/path/to/jeb-apk-decompiler.jar
```

## killx

`killx` 用来按完整命令行模式或按 TCP 监听端口查找进程，并选择性终止它们。

默认行为是预览，不会真的杀进程。只有加 `-y` 或 `--yes` 才会发送信号。

### 用法

```bash
killx -n <pattern> [options]
killx -p <port> [options]
```

可选参数：

- `-n, --name`：按完整命令行匹配进程，内部使用 `pgrep -f`
- `-p, --port`：按 TCP 监听端口匹配进程，内部使用 `lsof`
- `-y, --yes`：实际发送信号；默认只预览
- `-9, --force`：发送 `SIGKILL`；默认发送 `SIGTERM`
- `-h, --help`：查看帮助

### 示例

预览匹配某个任务：

```bash
./killx -n 'http.server'
```

确认后终止：

```bash
./killx -n 'http.server' -y
```

预览占用 8080 端口的监听进程：

```bash
./killx -p 8080
```

## sync-managed-section

通用：把「内容源」合并进目标文件的标记托管段。

只改写 `<!-- <MARKER>:START -->` … `<!-- <MARKER>:END -->` 之间的内容，
其余（如 OMC/OMX 段、本机备注）一律保留。托管段**始终位于文件末尾**。

```bash
sync-managed-section \
  --content ~/.claude/CLAUDE.user.md \
  --target  ~/.claude/CLAUDE.md \
  --marker  CHEZMOI-USER

sync-managed-section --content ... --target ... --marker CHEZMOI-USER --status
sync-managed-section --content ... --target ... --marker CHEZMOI-USER --remove
```

- 标记按**整行精确匹配**解析：顺序错误、嵌套、未闭合、多段或含 CR/CRLF 会拒绝写入
- 内容源整行不得出现起止标记
- `--status`：已同步 exit 0，否则 1
- 实现：Python 3（stdlib only）

## sync-claude-prefs / sync-codex-prefs

`sync-managed-section` 的 Claude 与 Codex 薄封装：

| 命令 | 内容源 | 目标 | 标记 |
|------|--------|------|------|
| `sync-claude-prefs` | `~/.claude/CLAUDE.user.md`（仓库：`home/dot_claude/CLAUDE.user.md`） | `~/.claude/CLAUDE.md` | `CHEZMOI-USER` |
| `sync-codex-prefs` | `~/.codex/AGENTS.user.md`（仓库：`home/dot_codex/AGENTS.user.md`） | `~/.codex/AGENTS.md` | `CHEZMOI-USER` |

```bash
sync-claude-prefs            # 合并
sync-claude-prefs --status   # 仅检查（已同步 exit 0，否则 1）
sync-claude-prefs --remove   # 移除托管段

sync-codex-prefs             # 合并
sync-codex-prefs --status    # 仅检查（已同步 exit 0，否则 1）
sync-codex-prefs --remove    # 移除托管段
```

环境变量：

- Claude：`CLAUDE_USER_CONTENT` / `CLAUDE_USER_TARGET`
- Codex：`CODEX_USER_CONTENT` / `CODEX_USER_TARGET`

可选：`SYNC_MANAGED_SECTION` 指向 core 可执行文件。

## chezmoi 自动同步

`home/.chezmoiscripts/common/run_onchange_after_50-sync-agent-prefs.sh.tmpl`

- `CLAUDE.user.md` 或 `AGENTS.user.md` 变更时触发
- 依次调用 `sync-claude-prefs` 与 `sync-codex-prefs`；单个同步程序未部署时只跳过对应产品
- 任一同步失败时仍会尝试另一项，并在全部尝试后返回非零状态
- 合并逻辑不在钩子里，由薄封装 / `sync-managed-section` 负责
