#!/system/bin/sh
# 持续记录 recovery.log 到内部存储
# 用法: 在 TWRP 终端中运行 start_recovery_log.sh

LOG_FILE="/data/media/0/recovery_live.log"
PID_FILE="/tmp/recovery_logger.pid"

# 检查是否已经在运行
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "recovery logger already running (PID: $OLD_PID)"
        exit 0
    fi
fi

# 清空旧日志
echo "=== recovery.log live logging started at $(date) ===" > "$LOG_FILE"

# 启动后台循环记录
(
    while true; do
        cp /tmp/recovery.log "$LOG_FILE"
        sync
        sleep 1
    done
) &

# 保存 PID
echo $! > "$PID_FILE"
echo "recovery logger started (PID: $!, log: $LOG_FILE)"
echo "Log will be saved to /sdcard/recovery_live.log after reboot"
