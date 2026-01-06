#!/usr/bin/env python3
"""
创建带 Vivo AVB footer 的混合 recovery 镜像
自适应镜像大小。默认修补out里的镜像
claude真好用
"""
import sys
import os
import struct

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
VIVO_AVB_FOOTER = os.path.join(SCRIPT_DIR, "vivo_avb_footer.bin")
TARGET_SIZE = 100663296  # 96 MB recovery 分区大小
AVB_FOOTER_SIZE = 64
AVB_MAGIC = b"AVBf"

def parse_avb_footer(data):
    """解析 AVB footer，返回 (vbmeta_offset, vbmeta_size)"""
    if len(data) < AVB_FOOTER_SIZE:
        return None, None
    footer = data[-AVB_FOOTER_SIZE:]
    if footer[:4] != AVB_MAGIC:
        return None, None
    # AVB footer 结构 (big-endian):
    # 0-4: magic "AVBf"
    # 4-8: version_major
    # 8-12: version_minor  
    # 12-20: original_image_size
    # 20-28: vbmeta_offset
    # 28-36: vbmeta_size
    vbmeta_offset = struct.unpack(">Q", footer[20:28])[0]
    vbmeta_size = struct.unpack(">Q", footer[28:36])[0]
    return vbmeta_offset, vbmeta_size

def create_avb_footer(vbmeta_offset, vbmeta_size, template_footer):
    """基于模板创建新的 AVB footer，更新 vbmeta_offset"""
    new_footer = bytearray(template_footer)
    struct.pack_into(">Q", new_footer, 20, vbmeta_offset)
    # vbmeta_size 保持原样 (来自 Vivo)
    return bytes(new_footer)

def main():
    if len(sys.argv) < 2:
        twrp_img = os.path.expanduser("~/twrp/out/target/product/k6853v1_64_6360/recovery.img")
    else:
        twrp_img = sys.argv[1]

    # 检查文件
    if not os.path.exists(VIVO_AVB_FOOTER):
        print(f"Error: {VIVO_AVB_FOOTER} not found")
        return 1
    if not os.path.exists(twrp_img):
        print(f"Error: {twrp_img} not found")
        return 1

    # 读取文件
    with open(twrp_img, "rb") as f:
        twrp_data = f.read()
    with open(VIVO_AVB_FOOTER, "rb") as f:
        vivo_data = f.read()

    # 解析 TWRP AVB footer
    twrp_vbmeta_offset, twrp_vbmeta_size = parse_avb_footer(twrp_data)
    if twrp_vbmeta_offset is None:
        print("Error: TWRP image has no valid AVB footer")
        return 1
    print(f"TWRP: vbmeta_offset={twrp_vbmeta_offset}, vbmeta_size={twrp_vbmeta_size}")

    # 解析 Vivo AVB footer (在文件末尾)
    vivo_vbmeta_offset, vivo_vbmeta_size = parse_avb_footer(vivo_data)
    if vivo_vbmeta_offset is None:
        print("Error: Vivo AVB file has no valid footer")
        return 1
    print(f"Vivo: vbmeta_offset={vivo_vbmeta_offset}, vbmeta_size={vivo_vbmeta_size}")

    # 提取各部分
    twrp_content = twrp_data[:twrp_vbmeta_offset]  # TWRP 内容 (不含签名)
    vivo_vbmeta = vivo_data[:vivo_vbmeta_size]     # Vivo VBMeta 签名数据
    vivo_footer = vivo_data[-AVB_FOOTER_SIZE:]     # Vivo AVB footer 模板

    print(f"TWRP content: {len(twrp_content)} bytes")
    print(f"Vivo VBMeta: {len(vivo_vbmeta)} bytes")

    # 计算新布局
    # [TWRP content][Vivo VBMeta][padding][AVB footer]
    new_vbmeta_offset = len(twrp_content)
    content_plus_vbmeta = new_vbmeta_offset + vivo_vbmeta_size
    padding_size = TARGET_SIZE - content_plus_vbmeta - AVB_FOOTER_SIZE

    if padding_size < 0:
        print(f"\nError: Image too large!")
        print(f"  TWRP content:  {len(twrp_content):>12} bytes")
        print(f"  Vivo VBMeta:   {vivo_vbmeta_size:>12} bytes")
        print(f"  AVB footer:    {AVB_FOOTER_SIZE:>12} bytes")
        print(f"  Total needed:  {content_plus_vbmeta + AVB_FOOTER_SIZE:>12} bytes")
        print(f"  Target size:   {TARGET_SIZE:>12} bytes")
        print(f"  Overflow:      {-padding_size:>12} bytes")
        return 1

    # 创建新 footer
    new_footer = create_avb_footer(new_vbmeta_offset, vivo_vbmeta_size, vivo_footer)

    # 写入混合镜像
    with open(twrp_img, "wb") as f:
        f.write(twrp_content)
        f.write(vivo_vbmeta)
        f.write(b"\x00" * padding_size)
        f.write(new_footer)

    print(f"\nSuccess! Created: {twrp_img}")
    print(f"  New vbmeta_offset: {new_vbmeta_offset}")
    print(f"  Padding: {padding_size} bytes")
    print(f"  Total: {TARGET_SIZE} bytes")
    return 0

if __name__ == "__main__":
    sys.exit(main())
