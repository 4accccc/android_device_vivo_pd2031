#!/bin/bash
#
# TWRP Vivo Y73s 补丁撤销
# 撤销所有已应用的补丁，恢复原始代码
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TWRP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "TWRP vivo Y73s data分区解密补丁撤销脚本"
echo "=========================================="
echo ""

# 撤销system/vold补丁
revert_vold_patches() {
    echo ">>> 撤销 system/vold 补丁..."
    cd "$TWRP_ROOT/system/vold"

    PATCH_DIR="$SCRIPT_DIR/system_vold"

    # 逆序撤销补丁
    for patch in $(ls -r "$PATCH_DIR"/*.patch 2>/dev/null); do
        if [ -f "$patch" ]; then
            patch_name=$(basename "$patch")
            echo "    撤销: $patch_name"

            if patch -p1 --dry-run -R < "$patch" > /dev/null 2>&1; then
                patch -p1 -R < "$patch"
                echo "    成功"
            else
                echo "    - 未应用或已撤销，跳过"
            fi
        fi
    done
}

echo "开始撤销补丁..."
echo ""

revert_vold_patches

echo ""
echo "=========================================="
echo "补丁撤销完成!"
echo "=========================================="
echo ""
