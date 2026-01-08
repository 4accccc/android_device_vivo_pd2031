#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/vivo/k6853v1_64_6360

# Touch firmware
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/vendor/firmware/TP-CONFIG-FW-PD2031-LCMID32-VER0x0023.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/TP-CONFIG-FW-PD2031-LCMID32-VER0x0023.bin \
    $(LOCAL_PATH)/recovery/root/vendor/firmware/TP-FW-PD2031-LCMID32-VER0x606040023.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/TP-FW-PD2031-LCMID32-VER0x606040023.bin \
    $(LOCAL_PATH)/recovery/root/vendor/firmware/touch_firmwares_recovery.bin:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/firmware/touch_firmwares_recovery.bin

# Debug脚本3个
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/bin/start_dmesg_log.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/start_dmesg_log.sh \
    $(LOCAL_PATH)/recovery/root/system/bin/stop_dmesg_log.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/stop_dmesg_log.sh \
    $(LOCAL_PATH)/recovery/root/system/bin/start_recovery_log.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/start_recovery_log.sh

# Android fstab for vold/fscrypt (标准Android格式，解密需要)
PRODUCT_COPY_FILES +=     $(LOCAL_PATH)/recovery/root/system/etc/fstab.mt6853:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/fstab.mt6853

# Touch update binary (use prebuilt module)
PRODUCT_PACKAGES += vts_app_recovery

# FBE decryption property (filenames cipher mode)
PRODUCT_PROPERTY_OVERRIDES += \
    ro.crypto.volume.filenames_mode=aes-256-cts
