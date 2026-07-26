---
name: check-mermaid
description: >
  编写 Markdown 文档时用 mermaid 作图，并在完成后用本 skill 的脚本校验全部 mermaid 代码块。
  在生成/修改含 mermaid 的 md、用户要求画图校验、或文档交付前自检时使用。
---

# check-mermaid — mermaid 作图与校验

生成 Markdown 需要画图时使用 mermaid，写完后必须校验通过再交付。

## 校验责任

- **写文档的子 agent**：写完后立刻自校验，**全部通过**才向主 agent 报告完成；报告本身即「校验通过」的承诺。
- **主 agent 自己写的**：自跑自校验。

## 脚本位置

- `<本 SKILL 目录>/scripts/check_mermaid.ts`

本 skill 目录即本 `SKILL.md` 所在目录（通常 `~/.agents/skills/check-mermaid`）。

## 调用方式

```bash
npx --yes tsx <本 SKILL 目录>/scripts/check_mermaid.ts <md文件绝对路径>
```

可选：`--keep-temp` 保留临时 `.mmd`/`.svg` 便于排错。

**mmdc 调用策略（脚本内已实现）**：

1. 优先 `mmdc`（PATH 中已安装，最快）
2. 否则 fallback 到 `npx --yes --package @mermaid-js/mermaid-cli mmdc`（首次会下载）
3. 两者都不可用 → 退出码 2

## 输出与退出码

退出码：

| 码 | 含义 |
|----|------|
| `0` | 全部通过 |
| `1` | 存在失败块（按 JSON 中失败块的 `error` 字段定位修复） |
| `2` | 环境问题（mmdc + npx 都不可用 / 文件不存在 / 参数错误） |

stdout 为 JSON：

```json
{
  "file": "<input>",
  "runner": "mmdc | npx",
  "total": 0,
  "passed": 0,
  "failed": 0,
  "blocks": [
    {
      "index": 1,
      "start_line": 0,
      "end_line": 0,
      "ok": true,
      "diagram_type": "flowchart",
      "error": "可选，原样回传 mmdc stderr",
      "snippet": "可选，失败块前几行"
    }
  ]
}
```

`error` **原样回传 mmdc stderr**，据此修复后重新跑脚本，直到退出码 0。

## 工作流

1. 在 md 中用 ` ```mermaid ` 代码块作图
2. 对目标 md 跑校验脚本
3. 若 `failed > 0`：按 `start_line` / `error` 修改对应块，再校验
4. 仅当退出码 0 时才报告文档完成
