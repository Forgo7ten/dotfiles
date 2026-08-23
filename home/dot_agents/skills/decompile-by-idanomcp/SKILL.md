---
name: decompile-by-idanomcp
description: 用 IDA-NO-MCP（inp 工具，基于 idalib 的无界面 IDA 引擎）反编译二进制文件（.so / 可执行文件 / .dylib / .i64 等），导出函数反编译、反汇编、字符串、导入导出表、调用图到目标文件同目录。当用户要求「反编译 xx 文件」「用 IDA 分析这个二进制/so」「导出反编译结果给 AI 分析」时使用。
---

# decompile-by-idanomcp

## 检查：inp.sh 可用性 + 版本漂移

```bash
command -v inp.sh                 # 命中说明 ~/.local/bin 在 PATH 里
test -x ~/.local/bin/inp.sh       # 绝对路径兜底
```

- 都失败 → 读取 [references/setup.md](references/setup.md) 完成初始化
- 命中第一条 → 后续用 `inp.sh`；只命中第二条 → 后续一律用绝对路径 `~/.local/bin/inp.sh`。然后校验 IDA 版本是否漂移：

```bash
IDA_APP=$(cat ~/.local/share/inp/ida-app 2>/dev/null)
CUR=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$IDA_APP/Contents/Info.plist" 2>/dev/null | cut -d. -f1-3)
[ -n "$CUR" ] && [ "$CUR" = "$(cat ~/.local/share/inp/ida-version 2>/dev/null)" ] && echo MATCH
```

- 输出 `MATCH` → 走下方「执行流程」
- 不一致 / stamp 缺失 / IDA_APP 失效 → 读取 [references/update.md](references/update.md) 完成更新后再走执行流程

## 执行流程

**执行交给快速模型子 agent（如 lite-executor），不要由主 agent 直接跑**（反编译耗时长、输出量大）。

下文 `INP` 指检查阶段确定的调用形式（`inp.sh` 或绝对路径 `~/.local/bin/inp.sh`）。

1. 先跑 `INP --help` 了解工具当前支持的参数，再按需带参执行；不设 `-o` 时默认输出到目标同目录的 `<文件名>_export_for_ai/`：

```bash
INP <目标文件的绝对路径>
```

- 文件较大（约 100MB 以上）或分析迟迟不结束：加 `--skip-analysis`
- 已有输出目录但想重来：加 `--force`

2. 向用户汇报：输出目录路径、函数总数 / 成功数（`exported=N failed=0`）、耗时。输出目录内有 `AGENTS.md` 索引各产物用途，需要细读产物时先看它。失败或结果异常时：先查 [references/troubleshooting.md](references/troubleshooting.md) → 未覆盖再查仓库 README（`$(ghq root)/github.com/P4nda0s/IDA-NO-MCP/README.md`）→ 仍无法解决则向用户报告原始报错，不盲目重试。
