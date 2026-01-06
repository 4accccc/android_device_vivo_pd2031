#!/bin/bash
#
# TWRP Vivo Y73S 补丁应用脚本
# 首次编译前运行一次
# 不运行解密不了分区！
# 原因是TWRP版本太高了(安卓12)不适配安卓10，需要重写整个Keymaster。
#

set -e

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TWRP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "TWRP vivo Y73s data分区解密补丁应用脚本"
echo "=========================================="
echo ""
echo "TWRP根目录: $TWRP_ROOT"
echo ""

# 检查TWRP根目录是否正确
if [ ! -d "$TWRP_ROOT/system/vold" ]; then
    echo "找不到 system/vold 目录"
    echo "请确保你在twrp源码目录运行这个脚本"
    exit 1
fi

# 应用system/vold补丁
apply_vold_patches() {
    echo ">>> 应用 system/vold 补丁..."
    cd "$TWRP_ROOT/system/vold"

    PATCH_DIR="$SCRIPT_DIR/system_vold"

    for patch in "$PATCH_DIR"/*.patch; do
        if [ -f "$patch" ]; then
            patch_name=$(basename "$patch")
            echo "    应用: $patch_name"

            # 检查补丁是否已应用
            if patch -p1 --dry-run -N < "$patch" > /dev/null 2>&1; then
                patch -p1 -N < "$patch"
                echo "    成功"
            else
                # 尝试反向检查是否已应用
                if patch -p1 --dry-run -R < "$patch" > /dev/null 2>&1; then
                    echo "    已应用，跳过"
                else
                    echo "    失败 (可能有冲突)"
                    echo "    请手动检查: $patch"
                fi
            fi
        fi
    done
}

echo "开始应用补丁..."
echo ""

apply_vold_patches

echo ""
echo "=========================================="
echo "补丁应用完成!"
echo "=========================================="
echo ""
echo "现在可以编译TWRP:"
echo "  cd $TWRP_ROOT"
echo "  source build/envsetup.sh"
echo "  lunch omni_k6853v1_64_6360-eng"
echo "  mka recoveryimage"
echo "  python3 device/vivo/k6853v1_64_6360/make_hybrid.py"
echo ""
