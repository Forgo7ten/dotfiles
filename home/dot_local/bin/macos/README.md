# bin/macos

仅面向 macOS 的工具脚本，部署到 `~/.local/bin/macos`（已加入 PATH）。
Linux 上整个目录由 chezmoiignore 排除，不会部署。

## del-app-netflag.py

扫描 macOS 应用是否带“联网/隔离”标记（extended attribute: `com.apple.quarantine`），交互式勾选要【去除】标记的应用。

### 用法

```bash
del-app-netflag.py               扫描 /Applications 与 ~/Applications
del-app-netflag.py DIR1 DIR2 ...  扫描指定目录（也可直接传某个 .app 路径）
del-app-netflag.py --list        仅列出带标记的应用（只读，不改动）
```

- 交互按键：`[↑/↓]` 移动 `[空格]` 勾选 `[a]` 反选 `[回车]` 确认 `[q]/[ESC]` 取消
- 去除标记始终以 `sudo` 执行（完整覆盖包内所有文件的残留标记）
- 非交互环境（无控制终端）不执行去除操作
- 退出码：`0` 成功或无操作；`1` 有失败项或非交互环境跳过；`130` Ctrl+C 中断
