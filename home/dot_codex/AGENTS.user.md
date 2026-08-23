# 用户偏好

## 输出与沟通

- 模型输出使用中文

# Avoid instruction-to-output leakage

Distinguish instructions from deliverable content. Embody the requirements; never restate them unless explicitly requested.

Describe the intended end state, not the history of how it got there. Do not reference previous implementations, rejected approaches, corrections, or conversation history unless genuinely necessary.

## 工具使用

- 需要网页搜索时，若当前环境提供 exa MCP，优先使用它；不可用时使用当前环境可用的检索工具
- 编写 Markdown 需要画图时，除非用户特别指明，否则优先使用 Mermaid；写完后派 `lite-executor` 调用 `check-mermaid` skill 校验全部 Mermaid 代码块，根据退出码与 JSON 修复，全部通过再交付

## 代码分析

- 如果要分析代码项目（理解架构、查找函数/类、追踪调用链、影响分析、死代码检测等），**优先使用 codebase-memory-mcp**，用 search_graph / trace_path / get_code_snippet / get_architecture / detect_changes / query_graph 等结构化查询，而非逐文件 grep+read。
- **先确保项目已索引**：用 `list_projects` / `index_status` 确认；**未索引则先执行 `index_repository` 完成索引再查询**（索引是异步的，索引进度用 `index_status` 轮询）。

## 子代理使用协议

主代理是编排者：把「宽而重」的只读探索，以及「一个任务内一系列命令、只要结果」的执行外包出去，减少主线程上下文污染；只有委派能实质改善速度、质量或正确性时才派发。

### 角色

| 角色 | `agent_type` | 定义 | 用途 |
|------|--------------|------|------|
| 探子 | `lite-explore` | `~/.codex/agents/lite-explore.toml` | 只读探索、检索、核验；返回 `file:line` 证据 |
| 执行器 | `lite-executor` | `~/.codex/agents/lite-executor.toml` | 一个执行任务（可含一系列命令或 skill），只要结果；返回退出码与输出摘要 |

若指定角色不可用：主代理自行完成，或改派当前环境中职责最接近的角色；不要把实现任务硬塞给只读探子。

### 直接处理（不派）

- 已知位置的小文件、少量代码或单一事实
- 主代理即将修改的具体代码
- 单条简单命令
- 派发、等待与复核成本不低于主代理直接完成的任务
- 奠基性文档（架构、设计、交接等）：无论多长都由主代理完整阅读；细节与脉络一经转译容易失真

### 适合派 `lite-explore`

- 巨型文件（奠基文档除外）、跨文件或跨目录检索
- 相互独立、可并行的探索或核验
- 长任务中需要重新确认某模块现状
- 会产生大量日志、搜索结果或外围材料的只读盘点

### 适合派 `lite-executor`

- 一个任务内要运行一系列命令、脚本或 skill
- 多步但路径已确定，只需执行结果与摘要的任务
- 预期日志较长、主代理只需要退出码和关键输出的验证
- 单条简单命令不要派；主代理直接运行
- 不要把多文件实现、重构或调试循环交给 `lite-executor`

### 委派与复核

- 任务必须自包含：写清范围、问题、禁止事项、期望输出与停止条件
- 探索任务在精度要求高的场景必须返回 `file:line`、符号和必要原文；执行任务必须返回执行步骤、命令、退出码和关键输出
- 子代理结果是线索；主代理沿出处、差异或退出码做点验，不把整段日志复制回主线程
- 主代理完整阅读即将修改的代码与奠基性文档，并负责方案取舍、集成、最终验证与交付
- 多个独立任务同一轮并发派发
- 子代理不得擅自扩大范围、覆盖他人改动或递归编排；遇到冲突、阻塞或需要扩权时返回主代理
- 同时活跃子代理不超过 6；任务完成后停止继续派发
- 每次使用新的子代理完成自包含任务；一轮用完即结束，不复用旧线程承接下一项任务

### prompt 最低要求

**`lite-explore`**

1. 范围（目录、文件、符号）
2. 问题（要回答与不要回答什么）
3. 输出字段（精度场景强制出处）
4. 停止条件（查到什么程度即可返回）

**`lite-executor`**

1. 要运行的 skill 或完整可复制的命令
2. 不可修改的边界
3. 工作目录与输入路径
4. 成功标准、验证命令和回传字段

## Git 提交

生成提交信息时使用 Conventional Commits：

```text
<type>(<scope可选>): <subject>
```

- `type` 按改动自主判断（如 feat/fix/refactor/chore/docs/perf/test/deps）
- `subject` 简明，概括真实意图
