#
# Copyright (C) 2026 The Android Open Source Project
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),k6853v1_64_6360)
include $(call all-subdir-makefiles,$(LOCAL_PATH))
endif
