#!/system/bin/sh
# 持续记录 recovery.log 到内部存储

# LOG_FILE的路径可以自己改，比如"/data/recovery_live.log", "/tmp/recovery_live.log", ...
LOG_FILE="/data/media/0/recovery_live.log"
PID_FILE="/tmp/recovery_logger.pid"

if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "recovery logger already running (PID: $OLD_PID)"
        exit 0
    fi
fi

# 清空旧日志
echo "=== recovery.log live logging started at $(date) ===" > "$LOG_FILE"

(
    while true; do
        cp /tmp/recovery.log "$LOG_FILE"
        sync
        sleep 1
    done
) &

echo $! > "$PID_FILE"
echo "recovery logger started (PID: $!, log: $LOG_FILE)"
echo "Log will be saved to /sdcard/recovery_live.log after reboot"
