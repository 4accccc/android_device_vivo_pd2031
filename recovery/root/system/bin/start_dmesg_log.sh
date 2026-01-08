#!/system/bin/sh
# 持续记录 dmesg 到内部存储
# 用法: 在 TWRP 终端中运行 start_dmesg_log.sh

LOG_FILE="/data/media/0/dmesg_live.txt"
PID_FILE="/tmp/dmesg_logger.pid"

# 检查是否已经在运行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "dmesg logger already running (PID: $OLD_PID)"
        exit 0
    fi
fi

# 清空旧日志
echo "=== dmesg live logging started at $(date) ===" > "$LOG_FILE"

# 启动后台循环记录
(
    while true; do
        dmesg > "$LOG_FILE"
        sync
        sleep 1
    done
) &

# 保存 PID
echo $! > "$PID_FILE"
echo "dmesg logger started (PID: $!, log: $LOG_FILE)"
