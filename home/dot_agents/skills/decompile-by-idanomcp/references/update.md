# 更新流程（IDA 升级 / 二进制与 IDA 版本不匹配时执行）

触发条件（满足其一）：

- SKILL 检查阶段发现 stamp 与本机 IDA 构建号不一致（或 stamp 缺失）
- 用户升级了 IDA
- 运行 inp 立即崩溃（疑似 idalib 与 IDA 版本错配）

## 第 1 步：读取当前 IDA 版本

```bash
ls -d /Applications/IDA*.app 2>/dev/null   # 若有多个，确认用户在用的那个
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$IDA_APP/Contents/Info.plist"
# 形如 9.3.260326.xxxx → 版本号取前三段 CUR=9.3.260326
```

IDA 换了新的 .app 路径（如从 IDA 9.3.app 换成 IDA 9.4.app）：重新生成包装脚本（按 setup.md 第 3c 步，用新的 `$IDA_APP`），并更新 `~/.local/share/inp/ida-app`。

## 第 2 步：判断是否需要重编译

```bash
grep -E '^idalib' "$REPO/Cargo.toml"   # REPO=$(ghq root)/github.com/P4nda0s/IDA-NO-MCP
```

按 setup.md 第 3a 步的方法在 crates.io 查 `+${CUR}` 精确匹配应使用的 idalib 版本。

- Cargo.toml 已 pin 到该版本、且 `$REPO/target/release/inp` 存在 → **无需重编译**，跳到第 4 步
- 否则 → 继续第 3 步

## 第 3 步：更新依赖并重编译

若想顺带跟进上游仓库更新（可选）——注意本地 `Cargo.toml` 有版本 pin 改动，先还回原样再拉，拉完重新 pin：

```bash
OLD=$(git -C "$REPO" rev-parse HEAD)   # 记下 pull 前位置，供第 4 步 diff README
git -C "$REPO" checkout -- Cargo.toml Cargo.lock
git -C "$REPO" pull
```

把 `Cargo.toml` 中 `idalib` 和 `idalib-build` 改成第 2 步确定的版本，然后按 setup.md 第 3b 步编译（env 变量不变，用新的 `$IDA_APP` 对应的 `IDADIR`）。

若 crates.io 上没有与 `CUR` 精确匹配的 idalib-sys：告知用户该 IDA 版本暂无对应 idalib，可选择回退 IDA 或等 idalib 跟进，**不要**用不匹配版本硬跑。

## 第 4 步：检查上游 README 变化（仅拉取了上游更新后执行）

```bash
git -C "$REPO" diff "$OLD"..HEAD -- README.md README_EN.md
```

对照 diff 确认编译流程（环境变量、idalib 版本对照、构建命令）和使用流程（命令行参数、输出目录结构）是否有变化：

- 无变化或与本 SKILL 无关 → 跳过
- 有变化且影响 SKILL 内容（setup.md 的构建步骤、SKILL.md 的检查/执行流程、troubleshooting.md 的症状对照）→ 列出拟改动点，**先询问用户意见**，同意后再改 SKILL 文件

## 第 5 步：更新 stamp 并验证

```bash
echo "$IDA_APP" > ~/.local/share/inp/ida-app
echo "$CUR" > ~/.local/share/inp/ida-version
```

冒烟测试同 setup.md 第 3d 步（`--help` + `/bin/ls` 副本端到端跑一次）。
