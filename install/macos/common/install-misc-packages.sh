#!/usr/bin/env bash

# 设置脚本在遇到错误时立即退出
# -E: 承接 ERR trap
# -e: 脚本中命令报错即退出
# -u: 使用未定义变量即报错
# -o pipefail: 管道命令中只要有一个失败，整个管道就视为失败
set -Eeuo pipefail

# 调试模式
if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

# 本脚本安装的工具会部署到 ~/.local/bin（如 mise），提前加入 PATH，
# 供后续各工具的已安装检测统一使用 command -v
export PATH="$HOME/.local/bin:$PATH"

# 定义 macOS 对应的软件包列表
readonly PACKAGES=(
    usbutils         # USB 设备信息查看工具
    wget             # 文件下载
    jq               # JSON 查询、过滤和转换工具
    ripgrep          # 高性能文本搜索工具（rg）
    fd               # 高性能文件查找工具，现代版 find
    fzf              # 命令行模糊搜索工具
    tree             # 以树形结构显示目录内容
    bat              # 带语法高亮和 Git 集成的 cat 替代工具
    eza              # 现代 ls 替代工具
    watch            # 周期性执行命令并刷新结果
    btop             # 系统资源和进程监控工具
    sevenzip         # 7zip

    temurin@21       # Java 21

    uv               # Python 包和项目管理工具
    yazi             # 终端文件管理器
    usage            # usage-spec CLI 工具，mise 相关组件
    chezmoi          # Dotfiles 管理工具
    zellij           # 终端多路复用和工作区管理工具

    age              # 文件加密工具
    shellcheck       # Shell 脚本静态检查工具
    shfmt            # Shell 脚本格式化工具
    bats-core        # Bash 自动化测试框架
    tree-sitter-cli  # Tree-sitter 命令行工具

    gh               # GitHub 官方 CLI
    ghq              # Git 仓库目录管理工具

    mole             # macOS 命令行清理与系统维护工具
)

# 定义 macOS 对应的 GUI 应用列表（brew install --cask 安装，brew 会自动处理已安装的项）
readonly CASK_PACKAGES=(
    squirrel-app                     # Rime 鼠鬚管
    input-source-pro                 # 输入法切换管理
    keka                             # 文件压缩与解压工具
    visual-studio-code               # VS Code
    010-editor                       # 十六进制编辑器
    dbx                              # dbx数据库
    clash-verge-rev                  # Clash 代理客户端
    google-chrome                    # Chrome 浏览器
    amir1376/tap/ab-download-manager # 下载管理器
)

# 检查 Homebrew 是否已安装
function check_brew() {
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew is not installed. Please install it first from https://brew.sh/"
        exit 1
    fi
}

function install_brew_packages() {
    if [ ${#PACKAGES[@]} -eq 0 ] && [ ${#CASK_PACKAGES[@]} -eq 0 ]; then
        # echo "No packages defined. Skipping installation."
        return 0
    fi
    echo "Updating Homebrew..."
    brew update

    # 使用 brew install 安装，brew 会自动处理已安装的包
    if [ ${#PACKAGES[@]} -gt 0 ]; then
        echo "Installing packages..."
        brew install "${PACKAGES[@]}"
    fi

    if [ ${#CASK_PACKAGES[@]} -gt 0 ]; then
        echo "Installing cask packages..."
        brew install --cask "${CASK_PACKAGES[@]}"
    fi
}

function uninstall_brew_packages() {
    echo "Uninstalling packages..."
    if [ ${#PACKAGES[@]} -gt 0 ]; then
        brew uninstall "${PACKAGES[@]}"
    fi
    if [ ${#CASK_PACKAGES[@]} -gt 0 ]; then
        brew uninstall --cask "${CASK_PACKAGES[@]}"
    fi
}

# 安装 mise（版本/运行时管理器）
# - 官方脚本默认安装到 ~/.local/bin/mise，幂等：已安装则跳过
function install_mise() {
    if command -v mise &> /dev/null; then
        echo "mise is already installed, skipping."
        return 0
    fi

    echo "Installing mise..."
    curl https://mise.run | sh
}

function install_other_packages() {
    install_mise
}

function main() {
    check_brew
    install_brew_packages
    install_other_packages
}

# 仅当脚本被直接执行（而非被 source）时调用 main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
