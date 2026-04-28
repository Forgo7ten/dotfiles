# bin

## jadx-remote

需要配置.env

```bash
export JADX_REMOTE_HOST=user@host
```

## jeb-remote

需要配置.env

```bash
export JEB_REMOTE_HOST=user@host
export JEB_REMOTE_JEB_HOME=/path/to/JEB
export JEB_REMOTE_JEB_FRONTEND_JAR=/path/to/jeb-apk-decompiler.jar
```

## killx

`killx` 用来按完整命令行模式或按 TCP 监听端口查找进程，并选择性终止它们。

默认行为是预览，不会真的杀进程。只有加 `-y` 或 `--yes` 才会发送信号。

### 用法

```bash
killx -n <pattern> [options]
killx -p <port> [options]
```

可选参数：

- `-n, --name`：按完整命令行匹配进程，内部使用 `pgrep -f`
- `-p, --port`：按 TCP 监听端口匹配进程，内部使用 `lsof`
- `-y, --yes`：实际发送信号；默认只预览
- `-9, --force`：发送 `SIGKILL`；默认发送 `SIGTERM`
- `-h, --help`：查看帮助

### 示例

预览匹配某个任务：

```bash
./killx -n 'http.server'
```

确认后终止：

```bash
./killx -n 'http.server' -y
```

预览占用 8080 端口的监听进程：

```bash
./killx -p 8080
```