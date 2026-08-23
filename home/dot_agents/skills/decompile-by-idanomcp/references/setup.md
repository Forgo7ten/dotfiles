# 初始化流程（仅 inp 命令不可用时执行）

按顺序执行以下三步。任何一步失败都停下来向用户报告，不要盲目继续。

## 第 1 步：查找本机 IDA 安装位置（macOS）

```bash
ls -d /Applications/IDA*.app 2>/dev/null
```

- 找到（如 `/Applications/IDA Professional 9.3.app`）：校验 `$IDA_APP/Contents/MacOS/libida.dylib` 存在，并读取版本：

```bash
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$IDA_APP/Contents/Info.plist"
# 输出形如 9.3.260213.91fc47de → 取第 3 段为构建号 BUILD=260213
```

- 没找到：询问用户 IDA.app 的完整路径，再继续。要求 **IDA 9.x**。

以下步骤中：

```bash
IDA_MACOS="$IDA_APP/Contents/MacOS"
```

## 第 2 步：用 ghq 获取 IDA-NO-MCP 仓库

```bash
ghq root   # 通常是 ~/ghq
ls ~/ghq/github.com/P4nda0s/IDA-NO-MCP 2>/dev/null || ghq get https://github.com/P4nda0s/IDA-NO-MCP
```

仓库位置即 `$(ghq root)/github.com/P4nda0s/IDA-NO-MCP`，以下记为 `REPO`。

若已存在，先检查 `Cargo.toml` 里的 idalib 版本是否与本机 IDA 匹配（见第 3 步），不匹配才需要改。

## 第 3 步：匹配 IDA 版本 → 编译 → 创建执行脚本

### 3a. 匹配 idalib 版本

idalib 硬编码了 IDA 内部类的虚函数表偏移，**必须与本机 IDA 构建号严格对应**。

用第 1 步拿到的构建号，在 crates.io 上找 build metadata 精确匹配的 idalib-sys 版本：

```bash
curl -s https://crates.io/api/v1/crates/idalib-sys/versions \
  | python3 -c "import json,sys; [print(v['num']) for v in json.load(sys.stdin)['versions'] if not v['yanked']]" \
  | grep "+9.3.${BUILD}"   # 9.3 换成本机 IDA 的 次版本号
```

- 命中（如 `0.8.1+9.3.260213`）：取 `+` 前的版本号，把 `$REPO/Cargo.toml` 中 `idalib` 和 `idalib-build` 都改成该版本
- 未命中：参考仓库 README 的版本对照表取最近匹配；都没有则告知用户「该 IDA 版本暂无对应 idalib」，停止

### 3b. 编译

```bash
cd "$REPO"
export PATH="$HOME/.cargo/bin:$PATH"   # Rust 工具链（mise/rustup 均可）；没有 cargo 就先装 Rust
export IDADIR="$IDA_MACOS"
export LIBCLANG_PATH="/Library/Developer/CommandLineTools/usr/lib"   # bindgen 需要；xcode-select -p 可定位
export CXXFLAGS="-DUSE_DANGEROUS_FUNCTIONS"
cargo build --release
```

`CXXFLAGS` 不能省，否则编译报 `dont_use_snprintf` 未声明（详见 troubleshooting.md）。

产物：`$REPO/target/release/inp`

### 3c. 创建执行脚本 ~/.local/bin/inp.sh

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/inp.sh <<EOF
#!/bin/bash
export IDADIR="$IDA_MACOS"
export DYLD_LIBRARY_PATH="\$IDADIR"
exec "$REPO/target/release/inp" "\$@"
EOF
chmod +x ~/.local/bin/inp.sh
```

### 3d. 记录版本 stamp 并验证

写入版本 stamp（供 SKILL 检查阶段做版本漂移检测）：

```bash
mkdir -p ~/.local/share/inp
echo "$IDA_APP" > ~/.local/share/inp/ida-app
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$IDA_APP/Contents/Info.plist" \
  | cut -d. -f1-3 > ~/.local/share/inp/ida-version    # 形如 9.3.260213
```

验证：

```bash
~/.local/bin/inp.sh --help    # 打印用法即成功（出现 IDA 的问候语说明 license 正常）
cp /bin/ls /tmp/inp_smoke && ~/.local/bin/inp.sh /tmp/inp_smoke -o /tmp/inp_smoke_out
# 看到 "done in Xs — exported=N failed=0" 且 /tmp/inp_smoke_out 下有 decompile/ 等目录即端到端通过
rm -rf /tmp/inp_smoke /tmp/inp_smoke_out /tmp/inp_smoke_export_for_ai
```

SKILL 内部始终用绝对路径 `~/.local/bin/inp.sh` 调用，不依赖用户 PATH。
