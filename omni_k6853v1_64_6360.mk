#
# Copyright (C) 2026 The Android Open Source Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Omni stuff.
# $(call inherit-product, vendor/omni/config/common.mk)

# Inherit from k6853v1_64_6360 device
$(call inherit-product, device/vivo/k6853v1_64_6360/device.mk)

PRODUCT_DEVICE := k6853v1_64_6360
PRODUCT_NAME := omni_k6853v1_64_6360
PRODUCT_BRAND := vivo
PRODUCT_MODEL := vivo
PRODUCT_MANUFACTURER := vivo

PRODUCT_GMS_CLIENTID_BASE := android-vivo

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="full_k6853v1_64_6360-user 10 QP1A.190711.020 compiler10052108 release-keys"

BUILD_FINGERPRINT := vivo/PD2031/PD2031:10/QP1A.190711.020/compiler10052108:user/release-keys
