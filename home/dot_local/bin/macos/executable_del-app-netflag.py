#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# ///
"""
del-app-netflag.py —— 单文件工具：扫描 macOS 应用是否带“联网/隔离”标记
(extended attribute: com.apple.quarantine)，并用交互式复选框勾选要
【去除】标记的应用。从网络下载的 App 会被打上 com.apple.quarantine，
从而触发 Gatekeeper 审查并限制其联网，“去标记”即删除该属性。

用法:
    del-app-netflag.py               扫描 /Applications 与 ~/Applications
    del-app-netflag.py DIR1 DIR2 ...  扫描指定目录（也可直接传某个 .app 路径）
    del-app-netflag.py --list        仅列出带标记的应用（只读，不改动）

交互按键: [↑/↓] 移动  [空格] 勾选  [a] 反选  [回车] 确认  [q]/[ESC] 取消
粘贴内容会被整体忽略（bracketed paste），不会当作按键。
同名应用以 Foo.app(上级目录) 区分；去除标记始终以 sudo 执行。
退出码:   0 成功或无操作；1 有失败项或非交互环境跳过；130 Ctrl+C 中断
非交互环境（无控制终端）不执行去除操作。
"""

import os
import select
import signal
import subprocess
import sys
import termios
import tty
from collections import Counter

QUAR = "com.apple.quarantine"


def collect_apps(root, maxdepth=3):
    """返回 root 下所有 .app bundle 的绝对路径（不深入 bundle 内部）。"""
    out = []
    root = os.path.abspath(root)
    if not os.path.isdir(root):
        print(f"  [跳过·不存在] {root}", file=sys.stderr)
        return out
    for dp, dirnames, filenames in os.walk(root):
        depth = dp[len(root) :].count(os.sep) if dp.startswith(root) else 0
        if depth >= maxdepth:
            dirnames[:] = []
            continue
        for nm in list(dirnames):
            if nm.endswith(".app"):
                out.append(os.path.join(dp, nm))
                dirnames.remove(nm)
    return out


def has_flag(path):
    r = subprocess.run(
        ["xattr", path], capture_output=True, encoding="utf-8", errors="replace"
    )
    return any(line.strip() == QUAR for line in r.stdout.splitlines())


def strip_flag(path):
    """删除隔离标记，返回 (是否成功, 失败原因或 None)。

    始终以 sudo 执行：避免普通权限只删掉 bundle 根上的标记、包内残留
    却因根目录已无标记而“隐身”的问题；sudo 能完整覆盖包内所有文件。
    """
    r = subprocess.run(
        ["sudo", "xattr", "-dr", QUAR, path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        encoding="utf-8",
        errors="replace",
    )
    return r.returncode == 0, (r.stderr or "").strip() or None


# ---------------------------------------------------------------- 交互界面
def open_tty():
    try:
        return open("/dev/tty", "r+b", buffering=0)
    except OSError:
        return None  # 无控制终端（管道/CI）


class KeyReader:
    """带缓冲的按键读取器。

    一次 os.read 可能同时读到多个按键（快速连按），逐个消费不丢键；
    完整解析转义序列——CSI（ESC [ 参数... final，覆盖 Ctrl+↑ 等带修饰
    参数的方向键）与 SS3（ESC O A/B/C/D），序列整体消费、不残留误判；
    启用 bracketed paste 后，粘贴内容被 ESC[200~ ... ESC[201~ 包裹，
    整段识别并丢弃，绝不作为按键处理；ESC 单独按下（50ms 内无后续
    字节）识别为 "esc"。
    """

    _ARROWS = {b"A": "up", b"B": "down", b"C": "right", b"D": "left"}
    _NAMES = {
        b" ": "space",
        b"\r": "enter",
        b"\n": "enter",
        b"\x03": "ctrl-c",
        b"\x04": "ctrl-d",
        b"a": "a",
        b"A": "a",
        b"q": "q",
        b"Q": "q",
        b"k": "up",
        b"j": "down",
    }
    _PASTE_END = b"\x1b[201~"

    def __init__(self, f):
        self.f = f
        self.buf = b""

    def _fill(self, timeout=None):
        """再读一段字节进缓冲；timeout=None 表示阻塞读。返回是否读到。"""
        fd = self.f.fileno()
        try:
            if timeout is not None:
                r, _, _ = select.select([fd], [], [], timeout)
                if not r:
                    return False
            chunk = os.read(fd, 64)
        except OSError:
            return False  # 读取出错：视作无输入，绝不当作回车
        if not chunk:
            return False  # EOF
        self.buf += chunk
        return True

    def _discard_paste(self):
        """丢弃一段粘贴内容（直至结束符 ESC[201~）。"""
        while True:
            pos = self.buf.find(self._PASTE_END)
            if pos != -1:
                self.buf = self.buf[pos + len(self._PASTE_END) :]
                return
            if not self._fill(timeout=0.5):  # 迟迟等不到结束符：放弃并清空
                self.buf = b""
                return

    def next_key(self):
        """返回规范按键名；EOF 或读取出错返回 None。"""
        while not self.buf:
            if not self._fill():
                return None
        b, self.buf = self.buf[:1], self.buf[1:]
        if b != b"\x1b":
            return self._NAMES.get(b, "unknown")
        # ESC 开头：转义序列，或单独按下的 ESC
        if not self.buf and not self._fill(timeout=0.05):
            return "esc"
        kind = self.buf[:1]
        if kind == b"[":  # CSI: ESC [ 参数... final byte(0x40-0x7E)
            self.buf = self.buf[1:]
            params = b""
            while True:
                if not self.buf and not self._fill(timeout=0.05):
                    self.buf = b""  # 残缺序列，丢弃
                    return "unknown"
                c, self.buf = self.buf[:1], self.buf[1:]
                if 0x40 <= c[0] <= 0x7E:
                    if c == b"~" and params == b"200":  # 粘贴开始：整段丢弃
                        self._discard_paste()
                        return "unknown"
                    if c == b"~" and params == b"201":  # 残留的粘贴结束符
                        return "unknown"
                    # 带修饰参数的方向键（如 Ctrl+↑ 的 \x1b[1;5A）按方向归类
                    return self._ARROWS.get(c, "unknown")
                params += c
        if kind == b"O":  # SS3: ESC O A/B/C/D
            while len(self.buf) < 2 and self._fill(timeout=0.05):
                pass
            if len(self.buf) >= 2:
                seq, self.buf = self.buf[1:2], self.buf[2:]
                return self._ARROWS.get(seq, "unknown")
            self.buf = b""  # 残缺序列，丢弃
            return "unknown"
        self.buf = self.buf[1:]  # ESC+普通键（Alt 组合）：一并吞掉
        return "unknown"


def pick(f, options):
    """在 tty 上做复选框多选，返回被勾选项的下标列表；取消返回 None。

    终端置于 cbreak 模式：Ctrl+C/Ctrl+Z 交给系统信号处理（中断/挂起），
    Ctrl+C 以 KeyboardInterrupt 抛出，由调用方统一处理。
    同名应用显示为 Foo.app(上级目录)，其余只显示 basename。
    启用 bracketed paste（ESC[?2004h）使粘贴可被识别并整体忽略；
    退出时清屏并还原，避免菜单残留及后续消息粘连；窗口尺寸变化
    （SIGWINCH）时立即重绘。
    """
    n = len(options)
    checked = [False] * n
    idx = 0
    reader = KeyReader(f)
    fd = f.fileno()
    attrs = termios.tcgetattr(fd)
    tty.setcbreak(fd)

    base = [os.path.basename(p) for p in options]
    dups = {b for b, c in Counter(base).items() if c > 1}
    labels = [
        f"{b}({os.path.dirname(p)})" if b in dups else b for b, p in zip(base, options)
    ]

    def render():
        hs = os.get_terminal_size(fd).lines
        rows = max(1, min(n, hs - 4))
        top = max(0, min(idx - rows + 1, n - rows))
        s = "\x1b[2J\x1b[H"
        s += (
            f"### 勾选要【去除】“联网/隔离”标记的应用 (已选 {sum(checked)}/{n}) ###\n\n"
        )
        for li in range(rows):
            gi = top + li
            m = "[x]" if checked[gi] else "[ ]"
            line = f"{'▶' if gi == idx else ' '} {m} {labels[gi]}"
            if gi == idx:
                line = "\x1b[7m" + line + "\x1b[0m"
            s += line + ("\n" if li != rows - 1 else "")
        s += "\n\n[↑/↓] 移动   [空格] 勾选   [a] 反选   [回车] 确认   [q/ESC] 取消"
        f.write(s.encode())
        f.flush()

    in_render = [False]

    def safe_render():
        # 供 SIGWINCH 处理器调用；防止与主线程正在进行的渲染嵌套导致花屏
        if in_render[0]:
            return
        in_render[0] = True
        try:
            render()
        except OSError:
            pass
        finally:
            in_render[0] = False

    def on_winch(signum, frame):
        safe_render()

    try:
        old_winch = signal.signal(signal.SIGWINCH, on_winch)
    except (ValueError, OSError, TypeError):
        old_winch = None  # 非主线程等场景：装不上就算了

    try:
        f.write(b"\x1b[?2004h")  # 启用 bracketed paste：粘贴可识别、可忽略
        f.flush()
        while True:
            render()
            k = reader.next_key()
            if k is None:  # EOF/读取出错 → 取消（绝不当作确认）
                return None
            if k in ("up", "left"):
                idx = max(0, idx - 1)
            elif k in ("down", "right"):
                idx = min(n - 1, idx + 1)
            elif k == "space":
                checked[idx] = not checked[idx]
            elif k == "a":
                checked[:] = [not c for c in checked]  # 逐项反选
            elif k == "enter":
                return [i for i, c in enumerate(checked) if c]
            elif k in ("q", "esc", "ctrl-c", "ctrl-d"):
                return None
            # 其余按键忽略
    finally:
        try:
            f.write(b"\x1b[?2004l\x1b[2J\x1b[H")  # 还原粘贴模式 + 清屏
            f.flush()
        except OSError:
            pass
        termios.tcsetattr(fd, termios.TCSADRAIN, attrs)
        if old_winch is not None:
            try:
                signal.signal(signal.SIGWINCH, old_winch)
            except (ValueError, OSError, TypeError):
                pass


# ------------------------------------------------------------------- 主流程
def main(argv):
    # 输出统一 UTF-8，避免异常 locale（如 LC_ALL=C）下应用名乱码/崩溃
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass

    list_only = False
    dirs = []
    positional = False
    for a in argv:
        if a == "--list":
            list_only = True
        elif a in ("--help", "-h"):
            print(__doc__)
            return 0
        elif a == "":
            positional = True
            print("  [忽略·空参数]", file=sys.stderr)
        else:
            positional = True
            dirs.append(os.path.expanduser(a))  # 支持 ~/... 由脚本自行展开

    if not dirs and not positional:  # 只有空参数时不回退默认目录
        dirs = ["/Applications", os.path.expanduser("~/Applications")]

    apps = []
    for d in dict.fromkeys(dirs):  # 去重且保持顺序
        d = os.path.normpath(os.path.abspath(d))  # 归一化尾斜杠等
        if d.endswith(".app"):  # 直接指定某个 .app
            if os.path.isdir(d):
                apps.append(d)
            else:
                print(f"  [跳过·不存在] {d}", file=sys.stderr)
        elif os.path.isdir(d):
            apps.extend(collect_apps(d))
        else:
            print(f"  [跳过·不存在] {d}", file=sys.stderr)
    apps = sorted(dict.fromkeys(apps))

    if not apps:
        print("未扫描到任何 .app。")
        return 0

    flagged = [a for a in apps if has_flag(a)]
    print(f"共扫描 {len(apps)} 个应用，其中 {len(flagged)} 个带“联网/隔离”标记:")
    for a in flagged:
        print(f"    - {a}")

    if list_only or not flagged:
        return 0

    tf = open_tty()
    if tf is None:
        print(
            "非交互环境（无控制终端），已跳过去除操作；"
            "可先用 --list 查看，或在终端中运行。"
        )
        return 1
    choice = pick(tf, flagged)
    if choice is None:
        print("已取消，未做任何修改。")
        return 0
    picked = [flagged[i] for i in choice]

    if not picked:
        print("未选择任何应用，未做修改。")
        return 0
    print(f"将去除以下 {len(picked)} 个应用的标记:")
    for p in picked:
        print(f"    - {p}")

    ok = fail = 0
    for p in picked:
        done, err = strip_flag(p)
        if done:
            print(f"  ✔ 已去除: {p}")
            ok += 1
        else:
            msg = f"  ✘ 失败:   {p}"
            if err:
                msg += f"\n      ↳ {err}"
            print(msg, file=sys.stderr)
            fail += 1
    print(f"\n完成：成功 {ok} 个，失败 {fail} 个。")
    return 0 if fail == 0 else 1


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except KeyboardInterrupt:
        print("\n已中断 (Ctrl+C)。")
        sys.exit(130)
