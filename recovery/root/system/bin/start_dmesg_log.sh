#!/system/bin/sh
# 持续记录 dmesg 到内部存储

# LOG_FILE的路径可以自己改，比如"/data/dmesg_live.txt", "/tmp/dmesg_live.txt", ...
LOG_FILE="/data/media/0/dmesg_live.txt"
PID_FILE="/tmp/dmesg_logger.pid"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "dmesg logger already running (PID: $OLD_PID)"
        exit 0
    fi
fi

# 清空旧日志
echo "=== dmesg live logging started at $(date) ===" > "$LOG_FILE"

(
    while true; do
        dmesg > "$LOG_FILE"
        sync
        sleep 1
    done
) &

echo $! > "$PID_FILE"
echo "dmesg logger started (PID: $!, log: $LOG_FILE)"
