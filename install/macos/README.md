

## 其他软件

这里记录了一些未预装、按需安装的软件。

```bash
cat > install.sh <<'EOF'
#!/usr/bin/env bash

# 磁盘空间分析
brew install --cask omnidisksweeper
# firefox浏览器
brew install --cask firefox
# Claude Code / Codex API 供应商切换工具
brew install --cask cc-switch
# 屏幕录制工具
brew install lihaoyun6/tap/quickrecorder
# 播放器
brew install --cask iina
# 增强鼠标功能（滚轮优化）
brew install --cask mos
# 菜单栏管理
brew install --cask thaw
# 截图工具
brew install --cask realskyrin/tap/capcap
# markdown编辑器
brew install --cask typora

# docker
brew install orbstack

# 增强鼠标功能（滚轮优化、按键映射等）
brew install --cask mac-mouse-fix
# 应用卸载工具（清理残留文件）
brew install --cask appcleaner

EOF

chmod +x install.sh

./install.sh

```
