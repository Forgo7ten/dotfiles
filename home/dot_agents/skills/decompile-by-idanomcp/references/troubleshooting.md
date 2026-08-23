# 故障排查

执行 inp 出错时按症状对照处理。

**fallback**：本表未覆盖的症状，查上游仓库 README（`$(ghq root)/github.com/P4nda0s/IDA-NO-MCP/README.md`，英文版 README_EN.md）找对应说明；仍无法解决再向用户报告原始报错，不要反复重试。

| 症状 | 原因 | 处置 |
|------|------|------|
| `Error: failed to open <input>` / `could not open IDA database: error code 2` | 输入路径不存在，或所在目录只读（`/bin`、`.app` 内部等） | 把文件复制到可写目录再跑，并告知用户分析的是副本 |
| 启动即段错误 / 崩溃在 libida | idalib 与 IDA 构建号不匹配（IDA 升级过） | 走 [update.md](update.md) 重新编译 |
| `dyld: Library not loaded: @rpath/libida.dylib` | 绕过了包装脚本，`DYLD_LIBRARY_PATH` 未设置 | 用 `~/.local/bin/inp.sh` 调用，不要直接调 target 里的二进制 |
| 没有输出 `Thank you for using IDA` 问候语，或报 license 相关错误 | IDA license 未激活或失效 | 让用户打开一次 IDA GUI 确认激活状态 |
| 长时间卡在分析阶段（十几分钟无输出） | 大二进制的自动分析 | 中断后加 `--skip-analysis` 重跑 |
| 编译报 `use of undeclared identifier 'dont_use_snprintf'` | 漏了 `CXXFLAGS="-DUSE_DANGEROUS_FUNCTIONS"` | 按 setup.md 第 3b 步带齐环境变量重编译 |
| 编译报链接错误、找不到 ida 库 | `IDADIR` 没指对 | 确认指向 `$IDA_APP/Contents/MacOS` 且其中存在 `libida.dylib` |
| 跑完但 `failed` 计数大于 0 | 个别函数反编译失败（混淆、异常控制流），属正常现象 | 看 `function_index.txt` 与 `decompile/` 确认主体完整；失败比例异常高时再深究 |
