#!/system/bin/sh
#
# 自动从系统分区读取安全补丁级别并应用
#
# 此脚本 **必须** 在 keymaster 启动前执行
# This script **MUST** run before keymaster launched.
#

LOG_TAG="AutoPatchLevel"
RESETPROP="/system/bin/resetprop"
RECOVERY_LOG="/tmp/recovery.log"

# 日志输出到 recovery.log 和 stderr
log_info() {
    local msg="I:[$LOG_TAG] $1"
    echo "$msg" >> "$RECOVERY_LOG"
    echo "$msg" >&2
}

log_error() {
    local msg="E:[$LOG_TAG] ERROR: $1"
    echo "$msg" >> "$RECOVERY_LOG"
    echo "$msg" >&2
}

# 检查 resetprop 是否可用
check_resetprop() {
    if [ ! -x "$RESETPROP" ]; then
        # 尝试其他位置
        for path in /sbin/resetprop /system/bin/resetprop /vendor/bin/resetprop; do
            if [ -x "$path" ]; then
                RESETPROP="$path"
                return 0
            fi
        done
        log_error "resetprop not found"
        return 1
    fi
    return 0
}

# 读取属性值的函数
read_prop_from_file() {
    local file="$1"
    local prop="$2"
    if [ -f "$file" ]; then
        grep "^${prop}=" "$file" 2>/dev/null | cut -d'=' -f2 | head -1
    fi
}

# 尝试映射动态分区
map_dynamic_partition() {
    local partition="$1"

    # 方法1: 使用 lptools (Magisk)
    if [ -x "/system/bin/lptools" ]; then
        log_info "Using lptools to map $partition"
        /system/bin/lptools map "$partition" 2>/dev/null
        return $?
    fi

    # 方法2: 使用 dmctl (Android)
    if [ -x "/system/bin/dmctl" ]; then
        log_info "Using dmctl to map $partition"
        /system/bin/dmctl create "$partition" 2>/dev/null
        return $?
    fi

    # 方法3: 使用 TWRP 的 sgdisk + dmsetup 组合 (如果有)
    if [ -x "/sbin/dmsetup" ]; then
        log_info "Trying dmsetup..."
        # 懒得写
    fi

    return 1
}

# 设置安全补丁级别属性
set_security_patch() {
    local patch_level="$1"

    if [ -z "$patch_level" ]; then
        log_error "Empty patch level"
        return 1
    fi

    log_info "Setting security patch level to: $patch_level"

    # 设置 system 相关的安全补丁属性
    # 注意: ro.vendor.build.security_patch 不需要改，Y73S vendor 分区从未更新过
    $RESETPROP ro.build.version.security_patch "$patch_level"
    $RESETPROP ro.system.build.version.security_patch "$patch_level"

    # 验证设置是否成功
    local verify=$($RESETPROP ro.build.version.security_patch 2>/dev/null)
    if [ "$verify" = "$patch_level" ]; then
        log_info "Security patch properties set successfully"
        # 设置标志表示完成
        $RESETPROP recovery.security_patch.ready 1
        return 0
    else
        log_error "Failed to verify security patch property"
        return 1
    fi
}

# 从 super 分区直接搜索 build.prop 内容
# 这是一个 fallback 方法，直接从 raw 分区搜索
# 但是缺点很明显，会导致开机变慢
search_in_super() {
    local super_dev="/dev/block/by-name/super"

    if [ ! -e "$super_dev" ]; then
        return 1
    fi

    log_info "Searching security_patch in super partition..."

    # 方法1: 使用 grep -a 直接搜索块设备 (更快)
	# 参数详细解释
    # -a: 将二进制文件当作文本处理
    # -o: 只输出匹配部分
    # -m 1: 找到第一个就停止
    local result=$(grep -a -o "ro.build.version.security_patch=[0-9-]*" "$super_dev" 2>/dev/null | head -1 | cut -d'=' -f2)

    if [ -n "$result" ]; then
        log_info "Found security_patch in super: $result"
        echo "$result"
        return 0
    fi

    # 方法2: 如果 grep 失败，尝试用 strings (分段搜索)
    log_info "grep failed, trying strings method..."

    # 搜索前 200MB (分 4 段，每段 50MB)
    for skip in 0 50 100 150; do
        result=$(dd if="$super_dev" bs=1M skip=$skip count=50 2>/dev/null | strings | grep "^ro.build.version.security_patch=" | head -1 | cut -d'=' -f2)
        if [ -n "$result" ]; then
            log_info "Found security_patch at offset ${skip}MB: $result"
            echo "$result"
            return 0
        fi
    done

    return 1
}

# 主程序从这里才开始

main() {
    log_info "Starting auto patch level detection..."
    log_info "Script version: v1"

    # 先检查 resetprop
    if ! check_resetprop; then
        exit 1
    fi
    log_info "Using resetprop: $RESETPROP"

    local security_patch=""
    local mount_point="/tmp/system_mount"
    local mounted=0

    # 创建临时挂载点
    mkdir -p "$mount_point"

    # ============================================================
    # 方法1: 从已挂载的位置读取
    # ============================================================
    for prop_file in \
        "/system_root/system/build.prop" \
        "/system/system/build.prop" \
        "/system/build.prop" \
        "/mnt/system/system/build.prop" \
        "/mnt/system/build.prop"
    do
        if [ -f "$prop_file" ]; then
            log_info "Reading from $prop_file"
            security_patch=$(read_prop_from_file "$prop_file" "ro.build.version.security_patch")
            if [ -n "$security_patch" ]; then
                log_info "Found: $security_patch"
                break
            fi
        fi
    done

    # ============================================================
    # 方法2: 尝试映射并挂载动态分区
    # ============================================================
    if [ -z "$security_patch" ] && [ -e "/dev/block/by-name/super" ]; then
        log_info "Super partition found, trying dynamic partition mapping..."

        # 尝试映射 system (non-A/B) 或 system_a (A/B), 在y73s上只能是前者non-A/B
        for part_name in system system_a; do
            map_dynamic_partition "$part_name"
            sleep 1

            local dm_dev="/dev/block/mapper/$part_name"
            if [ -e "$dm_dev" ]; then
                log_info "Attempting to mount $dm_dev"
                mount -t ext4 -o ro "$dm_dev" "$mount_point" 2>/dev/null
                if [ $? -eq 0 ]; then
                    mounted=1
                    # System-as-root: build.prop 在 /system/build.prop
                    # 非 SAR: build.prop 在 /build.prop
                    for bp in "$mount_point/system/build.prop" "$mount_point/build.prop"; do
                        if [ -f "$bp" ]; then
                            security_patch=$(read_prop_from_file "$bp" "ro.build.version.security_patch")
                            if [ -n "$security_patch" ]; then
                                log_info "Found from $dm_dev: $security_patch"
                                break 2
                            fi
                        fi
                    done
                    umount "$mount_point" 2>/dev/null
                    mounted=0
                fi
            fi
        done
    fi

    # ============================================================
    # 方法3: 直接从 super 分区搜索 (最后手段，较慢)
    # ============================================================
    if [ -z "$security_patch" ]; then
        log_info "Trying raw search in super partition..."
        security_patch=$(search_in_super)
    fi

    # ============================================================
    # 方法4: 从 /data/property/persistent_properties 读取
    # ============================================================
    if [ -z "$security_patch" ]; then
        local persist_prop="/data/property/persistent_properties"
        if [ -f "$persist_prop" ]; then
            log_info "Trying persistent properties..."
            security_patch=$(strings "$persist_prop" 2>/dev/null | grep "ro.build.version.security_patch" | cut -d'=' -f2 | head -1)
        fi
    fi

    # 清理
    if [ $mounted -eq 1 ]; then
        umount "$mount_point" 2>/dev/null
    fi
    rmdir "$mount_point" 2>/dev/null

    # ============================================================
    # 应用检测到的安全补丁级别
    # ============================================================
    if [ -n "$security_patch" ]; then
        set_security_patch "$security_patch"
        log_info "Auto patch level detection completed: $security_patch"
        return 0
    else
        log_error "Failed to detect security patch level"
        log_info "Dynamic partitions may not be mapped yet"
        log_info "Will use build-time default patch level"
        return 1
    fi
}

# 执行主函数
main
exit $?
