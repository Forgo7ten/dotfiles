#!/usr/bin/env python3
"""sync-managed-section: 将托管文本块合并进目标文件的标记段。

只改写 <!-- <MARKER>:START --> … <!-- <MARKER>:END --> 之间的内容，
其余（如 OMC/OMX 段）一律保留。托管段始终写在目标文件末尾。

示例:
  sync-managed-section --content ~/.claude/CLAUDE.user.md \\
                       --target  ~/.claude/CLAUDE.md \\
                       --marker  CHEZMOI-USER

  sync-managed-section --content ~/.codex/AGENTS.user.md \\
                       --target  ~/.codex/AGENTS.md \\
                       --marker  CHEZMOI-USER --status
"""

from __future__ import annotations

import argparse
import os
import random
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from pathlib import Path
from typing import List, Optional, Tuple


PROG = "sync-managed-section"


class MarkerKind(str, Enum):
    NONE = "none"
    ONE = "one"
    MULTI = "multi"
    CORRUPT = "corrupt"


@dataclass(frozen=True)
class MarkerAnalysis:
    kind: MarkerKind
    reason: str = ""
    # 唯一完整托管段的起止行下标（含标记行），仅 kind==ONE 时有效
    start_idx: Optional[int] = None
    end_idx: Optional[int] = None

    @property
    def label(self) -> str:
        if self.kind == MarkerKind.CORRUPT:
            return f"corrupt:{self.reason}"
        return self.kind.value


class SyncError(Exception):
    """面向用户的失败（进程退出码 1）。"""


def log(msg: str) -> None:
    print(f"[{PROG}] {msg}")


def fail(msg: str) -> None:
    raise SyncError(msg)


def marker_lines(marker_id: str) -> Tuple[str, str]:
    mid = marker_id.strip()
    if not mid:
        fail("marker id 不能为空")
    if any(ch.isspace() for ch in mid):
        fail(f"marker id 不可含空白: {mid!r}")
    if "-->" in mid or "<!--" in mid:
        fail(f"marker id 不可含 HTML 注释定界符: {mid!r}")
    return f"<!-- {mid}:START -->", f"<!-- {mid}:END -->"


def join_lines(lines: List[str], *, ensure_trailing_newline: bool = True) -> str:
    if not lines:
        return ""
    body = "\n".join(lines)
    if ensure_trailing_newline and not body.endswith("\n"):
        body += "\n"
    return body


def normalize_text(text: str) -> str:
    """去掉首尾空白行，并保证恰好以一个换行结尾。"""
    if "\r" in text:
        fail("仅支持 LF 换行（检测到 CR/CRLF）")
    lines = text.split("\n")
    # 去掉因末尾 \n 产生的尾部空串
    while lines and lines[-1] == "":
        lines.pop()
    while lines and lines[0].strip() == "":
        lines.pop(0)
    while lines and lines[-1].strip() == "":
        lines.pop()
    if not lines:
        return ""
    return "\n".join(lines) + "\n"


def analyze_markers(text: str, start: str, end: str) -> MarkerAnalysis:
    if "\r" in text:
        return MarkerAnalysis(MarkerKind.CORRUPT, reason="cr")

    lines = text.split("\n")
    # 若文件以 \n 结尾，split 会多一个尾部 ""，不会误匹配标记
    in_block = False
    complete = 0
    start_idx: Optional[int] = None
    end_idx: Optional[int] = None
    cur_start: Optional[int] = None

    for i, line in enumerate(lines):
        if line == start:
            if in_block:
                return MarkerAnalysis(MarkerKind.CORRUPT, reason="nested-start")
            in_block = True
            cur_start = i
            continue
        if line == end:
            if not in_block:
                return MarkerAnalysis(MarkerKind.CORRUPT, reason="unmatched-end")
            in_block = False
            complete += 1
            start_idx = cur_start
            end_idx = i
            cur_start = None
            continue

    if in_block:
        return MarkerAnalysis(MarkerKind.CORRUPT, reason="unclosed-start")
    if complete == 0:
        return MarkerAnalysis(MarkerKind.NONE)
    if complete == 1:
        return MarkerAnalysis(
            MarkerKind.ONE, start_idx=start_idx, end_idx=end_idx
        )
    return MarkerAnalysis(MarkerKind.MULTI)


def extract_inner(text: str, analysis: MarkerAnalysis) -> str:
    if analysis.kind != MarkerKind.ONE:
        fail(f"无法提取托管段（状态={analysis.label}）")
    assert analysis.start_idx is not None and analysis.end_idx is not None
    lines = text.split("\n")
    inner_lines = lines[analysis.start_idx + 1 : analysis.end_idx]
    return join_lines(inner_lines, ensure_trailing_newline=bool(inner_lines))


def strip_block(text: str, start: str, end: str) -> str:
    """剥离恰好一对完整托管段（含标记行）。调用前须已通过校验。"""
    analysis = analyze_markers(text, start, end)
    if analysis.kind != MarkerKind.ONE:
        fail(f"无法剥离托管段（状态={analysis.label}）")
    assert analysis.start_idx is not None and analysis.end_idx is not None
    lines = text.split("\n")
    del lines[analysis.start_idx : analysis.end_idx + 1]
    if not lines:
        return ""
    body = "\n".join(lines)
    # 原文以 \n 结尾时 split 会留尾部 ""，join 可保留 "a\n"。
    # 若剥离后丢失了尾换行，对文本文件予以补回。
    if text.endswith("\n") and not body.endswith("\n"):
        body += "\n"
    return body


def build_managed_block(normalized_inner: str, start: str, end: str) -> str:
    """normalized_inner 须已是 normalize_text() 的结果（带尾换行），空内容应已在上游拒绝。"""
    return f"{start}\n{normalized_inner}{end}\n"


def read_text(path: Path) -> str:
    """以 UTF-8 读取；newline='' 保留 CR/CRLF，便于检测。"""
    try:
        with path.open("r", encoding="utf-8", newline="") as fh:
            return fh.read()
    except UnicodeDecodeError as exc:
        fail(f"文件不是合法 UTF-8: {path} ({exc})")
    except OSError as exc:
        fail(f"读取失败: {path} ({exc})")


def ensure_not_symlink(path: Path) -> None:
    if path.is_symlink():
        fail(f"拒绝写入符号链接: {path}")


def file_mode(path: Path) -> Optional[int]:
    try:
        return path.stat().st_mode
    except OSError:
        return None


def atomic_write(path: Path, data: str, *, mode: Optional[int] = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=str(path.parent),
    )
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(data)
            fh.flush()
            os.fsync(fh.fileno())
        if mode is not None:
            os.chmod(tmp_path, mode & 0o777)
        os.replace(tmp_path, path)
    except Exception:
        try:
            tmp_path.unlink(missing_ok=True)
        except OSError:
            pass
        raise


def backup_target(path: Path) -> Path:
    stamp = datetime.now().strftime("%Y-%m-%d_%H%M%S")
    pid = os.getpid()
    last_err: Optional[Exception] = None
    for attempt in range(1, 17):
        rand = f"{random.randint(0, 0xFFFF):04x}{attempt:02x}"
        backup = path.with_name(f"{path.name}.backup.{stamp}.{pid}.{rand}")
        try:
            fd = os.open(str(backup), os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            continue
        except OSError as exc:
            last_err = exc
            continue
        try:
            data = path.read_bytes()
            with os.fdopen(fd, "wb") as fh:
                fh.write(data)
                fh.flush()
                os.fsync(fh.fileno())
            if backup.read_bytes() != data:
                backup.unlink(missing_ok=True)
                fail(f"备份校验失败: {backup}")
            log(f"已备份: {backup}")
            return backup
        except Exception as exc:
            try:
                backup.unlink(missing_ok=True)
            except OSError:
                pass
            last_err = exc
            fail(f"备份失败: {backup} ({exc})")
    detail = f" ({last_err})" if last_err else ""
    fail(f"无法创建独占备份（重试耗尽）: {path.name}.backup.{stamp}.*{detail}")


def validate_content(content: str, start: str, end: str) -> str:
    if "\r" in content:
        fail("内容源含 CR/CRLF，仅支持 LF")
    for line in content.split("\n"):
        if line == start or line == end:
            fail(f"内容源不可包含托管标记行 ({start} / {end})")
    normalized = normalize_text(content)
    if not normalized.strip():
        fail("内容源归一化后为空")
    return normalized


def validate_target_state(analysis: MarkerAnalysis, path: Path) -> None:
    if analysis.kind in (MarkerKind.NONE, MarkerKind.ONE):
        return
    if analysis.kind == MarkerKind.MULTI:
        fail(f"发现多个完整托管段，拒绝写入以免损坏: {path}")
    fail(f"标记结构异常({analysis.reason})，拒绝写入以免损坏: {path}")


def ends_with_newline(path: Path) -> bool:
    try:
        if path.stat().st_size == 0:
            return True
        with path.open("rb") as fh:
            fh.seek(-1, os.SEEK_END)
            return fh.read(1) == b"\n"
    except OSError:
        return False


def do_status(content_path: Path, target_path: Path, start: str, end: str) -> int:
    if not content_path.is_file():
        log(f"内容源不存在: {content_path}")
        return 1
    if not target_path.is_file():
        log(f"目标不存在: {target_path} （首次 merge 会创建）")
        return 1

    target_text = read_text(target_path)
    analysis = analyze_markers(target_text, start, end)
    if analysis.kind == MarkerKind.NONE:
        log("状态: 目标中尚无托管段")
        return 1
    if analysis.kind == MarkerKind.MULTI:
        log(f"警告: 发现多个完整托管段，建议检查 {target_path}")
        return 1
    if analysis.kind == MarkerKind.CORRUPT:
        log(f"警告: 标记结构异常({analysis.reason})，建议检查 {target_path}")
        return 1

    content_text = read_text(content_path)
    try:
        desired = normalize_text(content_text)
    except SyncError as exc:
        log(f"内容源异常: {exc}")
        return 1

    current = normalize_text(extract_inner(target_text, analysis))
    if current == desired:
        log(f"状态: 已同步 ({target_path})")
        return 0
    log("状态: 托管段与内容源不一致，需要更新")
    return 1


def do_remove(target_path: Path, start: str, end: str) -> int:
    ensure_not_symlink(target_path)
    if not target_path.is_file():
        fail(f"目标不存在: {target_path}")

    target_text = read_text(target_path)
    analysis = analyze_markers(target_text, start, end)
    validate_target_state(analysis, target_path)

    if analysis.kind == MarkerKind.NONE:
        log("无需移除: 目标中没有托管段")
        return 0

    backup_target(target_path)
    stripped = strip_block(target_text, start, end)
    # 规整首尾空白行；若无实质内容则写成 0 字节空文件
    normalized_base = normalize_text(stripped) if stripped.strip() else ""
    if not normalized_base.strip():
        out = ""
    else:
        out = normalized_base

    mode = file_mode(target_path)
    atomic_write(target_path, out, mode=mode)
    log(f"已移除托管段: {target_path}")
    return 0


def do_merge(content_path: Path, target_path: Path, start: str, end: str) -> int:
    ensure_not_symlink(target_path)
    if not content_path.is_file():
        fail(f"内容源不存在: {content_path}")
    if content_path.stat().st_size == 0:
        fail(f"内容源为空: {content_path}")

    content_text = read_text(content_path)
    desired_inner = validate_content(content_text, start, end)
    desired_block = build_managed_block(desired_inner, start, end)

    if not target_path.exists():
        atomic_write(target_path, desired_block)
        log(f"已创建: {target_path}")
        return 0

    if not target_path.is_file():
        fail(f"目标不是普通文件: {target_path}")

    target_text = read_text(target_path)
    analysis = analyze_markers(target_text, start, end)
    validate_target_state(analysis, target_path)

    if analysis.kind == MarkerKind.ONE:
        current_inner = normalize_text(extract_inner(target_text, analysis))
        if current_inner == desired_inner and ends_with_newline(target_path):
            log(f"已是最新，跳过: {target_path}")
            return 0

    backup_target(target_path)

    if analysis.kind == MarkerKind.ONE:
        base = strip_block(target_text, start, end)
    else:
        base = target_text

    # 规整 base 首尾；无实质内容则只写托管段
    if base.strip():
        # 去掉首尾空白行，内部内容原样保留
        base_lines = base.split("\n")
        while base_lines and base_lines[0].strip() == "":
            base_lines.pop(0)
        while base_lines and base_lines[-1].strip() == "":
            base_lines.pop()
        # 去掉原文尾换行带来的尾部空串
        base_body = "\n".join(base_lines)
        out = base_body + "\n\n" + desired_block
    else:
        out = desired_block

    mode = file_mode(target_path)
    atomic_write(target_path, out, mode=mode)
    log(f"已更新托管段: {target_path}")
    return 0


def build_parser() -> argparse.ArgumentParser:
    class ChineseHelpFormatter(argparse.RawDescriptionHelpFormatter):
        def add_usage(self, usage, actions, groups, prefix=None):
            if prefix is None:
                prefix = "用法: "
            return super().add_usage(usage, actions, groups, prefix)

    p = argparse.ArgumentParser(
        prog=PROG,
        description="将标记界定的托管文本块合并进目标文件。",
        epilog=(
            "说明:\n"
            "  托管段始终写在目标文件末尾；标记须整行精确匹配。\n"
            "  仅支持 LF 换行（含 CR/CRLF 会拒绝）。\n"
            "  --status 仅在已同步时退出码为 0，否则为 1。"
        ),
        formatter_class=ChineseHelpFormatter,
        add_help=False,
    )
    p.add_argument(
        "-h",
        "--help",
        action="help",
        default=argparse.SUPPRESS,
        help="显示帮助并退出",
    )
    p.add_argument(
        "--content",
        required=True,
        type=Path,
        help="托管内容源文件路径",
    )
    p.add_argument(
        "--target",
        required=True,
        type=Path,
        help="要更新的目标文本文件",
    )
    p.add_argument(
        "--marker",
        required=True,
        help="标记 ID，例如 CHEZMOI-USER → <!-- CHEZMOI-USER:START/END -->",
    )

    g = p.add_mutually_exclusive_group()
    g.add_argument(
        "--status",
        action="store_const",
        const="status",
        dest="action",
        help="仅检查同步状态（已同步则退出码 0）",
    )
    g.add_argument(
        "--remove",
        action="store_const",
        const="remove",
        dest="action",
        help="移除托管段，保留其余内容",
    )
    g.add_argument(
        "--merge",
        action="store_const",
        const="merge",
        dest="action",
        help="合并托管内容（默认）",
    )
    p.set_defaults(action="merge")
    p._optionals.title = "选项"
    # 互斥组标题（若显示）
    for grp in p._mutually_exclusive_groups:
        if grp.title is None:
            grp.title = "动作（互斥）"
    return p


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    start, end = marker_lines(args.marker)
    content = args.content.expanduser()
    target = args.target.expanduser()

    try:
        if args.action == "status":
            return do_status(content, target, start, end)
        if args.action == "remove":
            return do_remove(target, start, end)
        return do_merge(content, target, start, end)
    except SyncError as exc:
        print(f"[{PROG}] ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
