#!/bin/bash
#
# TWRP Vivo Y73S (PD2031) - 补丁撤销脚本
# 恢复原始代码
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TWRP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "TWRP Vivo Y73S (PD2031) 补丁撤销脚本"
echo "=========================================="
echo ""

revert_patches() {
    local target_dir="$1"
    local patch_dir="$2"
    local name="$3"

    if [ ! -d "$patch_dir" ]; then
        echo "    跳过 $name (补丁目录不存在)"
        return
    fi

    echo ">>> 撤销 $name 补丁..."
    cd "$target_dir"

    for patch in $(ls -r "$patch_dir"/*.patch 2>/dev/null); do
        if [ -f "$patch" ]; then
            patch_name=$(basename "$patch")
            echo "    撤销: $patch_name"

            if patch -p1 --dry-run -R < "$patch" > /dev/null 2>&1; then
                patch -p1 -R < "$patch"
                echo "    ✓ 成功"
            else
                echo "    - 未应用或已撤销，跳过"
            fi
        fi
    done
}

echo "开始撤销补丁..."
echo ""

revert_patches "$TWRP_ROOT/bootable/recovery" "$SCRIPT_DIR/bootable_recovery" "bootable/recovery"

revert_patches "$TWRP_ROOT/system/vold" "$SCRIPT_DIR/system_vold" "system/vold"

echo ""
echo "=========================================="
echo "补丁撤销完成!"
echo "=========================================="
echo ""
