#!/bin/bash
#
# TWRP Vivo Y73S (PD2031) - 补丁应用脚本
# 在编译前运行一次即可
#

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TWRP_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

echo "=========================================="
echo "TWRP Vivo Y73S (PD2031) 补丁应用脚本"
echo "=========================================="
echo ""
echo "TWRP根目录: $TWRP_ROOT"
echo ""

# 检查TWRP根目录是否正确
if [ ! -d "$TWRP_ROOT/system/vold" ]; then
    echo "错误: 找不到 system/vold 目录"
    echo "请确保从正确的TWRP源码目录运行此脚本"
    exit 1
fi

# 通用补丁应用函数
apply_patches() {
    local target_dir="$1"
    local patch_dir="$2"
    local name="$3"

    if [ ! -d "$patch_dir" ]; then
        echo "    跳过 $name (补丁目录不存在)"
        return
    fi

    echo ">>> 应用 $name 补丁..."
    cd "$target_dir"

    for patch in "$patch_dir"/*.patch; do
        if [ -f "$patch" ]; then
            patch_name=$(basename "$patch")
            echo "    应用: $patch_name"

            # 检查补丁是否已应用
            if patch -p1 --dry-run -N < "$patch" > /dev/null 2>&1; then
                patch -p1 -N < "$patch"
                echo "    ✓ 成功"
            else
                # 尝试反向检查是否已应用
                if patch -p1 --dry-run -R < "$patch" > /dev/null 2>&1; then
                    echo "    - 已应用，跳过"
                else
                    echo "    ✗ 失败 (可能有冲突)"
                    echo "    请手动检查: $patch"
					echo "    或者您也可以手动进行patch"
                fi
            fi
        fi
    done
}

# 主流程
echo "开始应用补丁..."
echo ""

# 应用 system/vold 补丁
apply_patches "$TWRP_ROOT/system/vold" "$SCRIPT_DIR/system_vold" "system/vold"

# 应用 bootable/recovery 补丁
apply_patches "$TWRP_ROOT/bootable/recovery" "$SCRIPT_DIR/bootable_recovery" "bootable/recovery"

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
echo ""
