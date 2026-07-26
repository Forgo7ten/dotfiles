#!/usr/bin/env -S npx tsx
/**
 * check_mermaid.ts — 校验 Markdown 文件中所有 ```mermaid ... ``` 代码块。
 *
 * 用法:
 *   npx --yes tsx check_mermaid.ts <markdown_file> [--keep-temp]
 *
 * mmdc 调用策略:
 *   1) 首选 `mmdc`（PATH 中已安装）
 *   2) 否则 fallback 到 `npx --yes --package @mermaid-js/mermaid-cli mmdc`
 *
 * 输出（stdout JSON）:
 *   {
 *     "file": "<input>",
 *     "runner": "mmdc" | "npx",
 *     "total": number,
 *     "passed": number,
 *     "failed": number,
 *     "blocks": [
 *       { index, start_line, end_line, ok, diagram_type, error?, snippet? }
 *     ]
 *   }
 *   error 字段原样回传 mmdc 的 stderr，由调用方（AI）自行判断如何修复。
 *
 * 退出码:
 *   0  全部通过
 *   1  存在失败块
 *   2  环境/参数错误（文件不存在 / mmdc 与 npx 都不可用）
 */

import { spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import process from 'node:process';

interface MermaidBlock {
  index: number;
  start_line: number;
  end_line: number;
  ok: boolean;
  diagram_type: string;
  error?: string;
  snippet?: string;
}

interface CheckResult {
  file: string;
  runner: 'mmdc' | 'npx' | 'none';
  total: number;
  passed: number;
  failed: number;
  blocks: MermaidBlock[];
}

const MERMAID_OPEN = /^[ \t]*```mermaid[ \t]*$/;
const MERMAID_CLOSE = /^[ \t]*```[ \t]*$/;

const DIAGRAM_TYPES = [
  'flowchart', 'graph', 'sequenceDiagram', 'classDiagram',
  'stateDiagram-v2', 'stateDiagram', 'erDiagram', 'journey',
  'gantt', 'pie', 'mindmap', 'timeline', 'gitGraph', 'C4Context',
];

function extractBlocks(md: string): Array<{ start: number; end: number; code: string }> {
  const lines = md.split(/\r?\n/);
  const blocks: Array<{ start: number; end: number; code: string }> = [];
  let i = 0;
  while (i < lines.length) {
    if (MERMAID_OPEN.test(lines[i])) {
      const start = i + 1;
      let j = i + 1;
      while (j < lines.length && !MERMAID_CLOSE.test(lines[j])) j++;
      if (j >= lines.length) {
        blocks.push({ start, end: lines.length, code: lines.slice(i + 1).join('\n') });
        break;
      }
      blocks.push({ start, end: j + 1, code: lines.slice(i + 1, j).join('\n') });
      i = j + 1;
    } else {
      i++;
    }
  }
  return blocks;
}

function detectDiagramType(code: string): string {
  for (const raw of code.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith('%%')) continue;
    for (const t of DIAGRAM_TYPES) {
      if (line.startsWith(t)) return t;
    }
    return 'unknown';
  }
  return 'unknown';
}

function commandExists(cmd: string): boolean {
  const r = spawnSync(process.platform === 'win32' ? 'where' : 'which', [cmd], { encoding: 'utf-8' });
  return r.status === 0 && (r.stdout || '').trim().length > 0;
}

type Runner = { type: 'mmdc' | 'npx' | 'none'; cmd: string; argsPrefix: string[] };

function pickRunner(): Runner {
  if (commandExists('mmdc')) {
    return { type: 'mmdc', cmd: 'mmdc', argsPrefix: [] };
  }
  if (commandExists('npx')) {
    return {
      type: 'npx',
      cmd: 'npx',
      argsPrefix: ['--yes', '--package', '@mermaid-js/mermaid-cli', 'mmdc'],
    };
  }
  return { type: 'none', cmd: '', argsPrefix: [] };
}

function renderOne(runner: Runner, code: string, workdir: string, keepTemp: boolean):
  { ok: boolean; stderr: string } {
  const inPath = path.join(workdir, `mmd-${Date.now()}-${Math.random().toString(36).slice(2)}.mmd`);
  const outPath = inPath.replace(/\.mmd$/, '.svg');
  try {
    writeFileSync(inPath, code.endsWith('\n') ? code : code + '\n', 'utf-8');
    const args = [...runner.argsPrefix, '-i', inPath, '-o', outPath, '-q'];
    const r = spawnSync(runner.cmd, args, { encoding: 'utf-8', timeout: 90_000 });
    const ok = r.status === 0 && existsSync(outPath);
    if (ok) return { ok: true, stderr: '' };
    let err = ((r.stderr || '') + (r.stdout || '')).trim();
    if (r.error) err = String(r.error.message) + '\n' + err;
    if (err.length > 1500) err = err.slice(0, 1500) + '\n...[truncated]';
    if (!err) err = `mmdc exited with status ${r.status}`;
    return { ok: false, stderr: err };
  } finally {
    if (!keepTemp) {
      try { rmSync(inPath, { force: true }); } catch {}
      try { rmSync(outPath, { force: true }); } catch {}
    }
  }
}

function firstLines(code: string, n = 5): string {
  return code.split(/\r?\n/).slice(0, n).join('\n');
}

function parseArgs(argv: string[]): { mdPath?: string; keepTemp: boolean; help: boolean } {
  const out = { mdPath: undefined as string | undefined, keepTemp: false, help: false };
  for (const a of argv) {
    if (a === '--help' || a === '-h') out.help = true;
    else if (a === '--keep-temp') out.keepTemp = true;
    else if (!a.startsWith('--') && !out.mdPath) out.mdPath = a;
  }
  return out;
}

function main(): number {
  const args = parseArgs(process.argv.slice(2));
  if (args.help || !args.mdPath) {
    console.error('Usage: npx --yes tsx check_mermaid.ts <markdown_file> [--keep-temp]');
    return args.help ? 0 : 2;
  }
  const mdPath = path.resolve(args.mdPath);
  if (!existsSync(mdPath)) {
    console.log(JSON.stringify({ error: `file not found: ${mdPath}` }));
    return 2;
  }

  const runner = pickRunner();
  if (runner.type === 'none') {
    console.log(JSON.stringify({
      error: 'Neither `mmdc` nor `npx` is available in PATH.',
    }));
    return 2;
  }

  const md = readFileSync(mdPath, 'utf-8');
  const blocks = extractBlocks(md);

  const workdir = mkdtempSync(path.join(tmpdir(), 'check-mermaid-'));
  const result: CheckResult = {
    file: mdPath,
    runner: runner.type,
    total: blocks.length,
    passed: 0,
    failed: 0,
    blocks: [],
  };

  try {
    blocks.forEach(({ start, end, code }, idx) => {
      const diagram_type = detectDiagramType(code);
      const { ok, stderr } = renderOne(runner, code, workdir, args.keepTemp);
      const block: MermaidBlock = {
        index: idx + 1,
        start_line: start,
        end_line: end,
        ok,
        diagram_type,
      };
      if (ok) {
        result.passed += 1;
      } else {
        result.failed += 1;
        block.error = stderr;
        block.snippet = firstLines(code);
      }
      result.blocks.push(block);
    });
  } finally {
    if (!args.keepTemp) {
      try { rmSync(workdir, { recursive: true, force: true }); } catch {}
    }
  }

  console.log(JSON.stringify(result, null, 2));
  return result.failed === 0 ? 0 : 1;
}

process.exit(main());
