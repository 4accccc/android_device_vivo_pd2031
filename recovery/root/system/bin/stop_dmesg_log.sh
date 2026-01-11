#!/system/bin/sh
# 停止 dmesg 日志记录
# 其实改一行就是停止 recovery 记录的，但是我懒

PID_FILE="/tmp/dmesg_logger.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    kill "$PID" 2>/dev/null
    rm "$PID_FILE"
    echo "dmesg logger stopped (PID: $PID)"
else
    echo "dmesg logger not running"
fi
