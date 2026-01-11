# TWRP for Y73s开发日志

给那些发现bug想要自己动手改device tree甚至改源码修复的人提供一下我修bug时的思路。看着玩也可以。

## 设备概述

**基础信息：**
- 型号: vivo Y73s
- 代号: PD2031
- SoC: MediaTek MT6853 (Dimensity 720)
- Android版本: 10 (SDK 29)
- 加密方式: FBE (File-Based Encryption) with aes-256-xts:aes-256-cts v1
- TEE: Trustonic MobiCore
- Keymaster: HIDL 4.0

---

## 第一阶段：基础环境搭建

### 设备树创建

使用 `twrpdtgen` 生成设备树   
创建 `device/vivo/k6853v1_64_6360/`   
最初的目录结构：

```
device/vivo/k6853v1_64_6360/
├── Android.bp
├── Android.mk
├── AndroidProducts.mk
├── BoardConfig.mk
├── device.mk
├── extract-files.sh
├── omni_k6853v1_64_6360.mk
├── README.md
├── recovery.fstab
├── setup-makefiles.sh
├── vendorsetup.sh
├── prebuilt/
│   ├── kernel
│   ├── dtb.img
│   └── dtbo.img
└── recovery/root/
    ├── init.recovery.mt6853.rc
    ├── init.recovery.platform.rc
    ├── init.recovery.svc.rc
    ├── init.recovery.touch.rc
    ├── init.recovery.wifi.rc
    └── ueventd.rc
```

### 最初状态

啥也用不了，除了TWRP加载界面有短暂的USB连接 (进主界面后USB连接断开) 以外就没了。

## 第二阶段：触摸屏修复

### 2.1 问题描述

TWRP启动后触摸屏无响应，无法进行任何操作。

### 2.2 原因分析

分析vivo官方rec后发现，vivo使用自定义触摸固件加载机制，需要从原厂的rec里提取：
1. 正确的产品型号属性 (`ro.vivo.product.model`)
2. 触控固件更新程序 (`vts_app_recovery`)

### 2.3 解决方案

**文件：** `init.recovery.mt6853.rc`

```rc
on early-init
    setprop ro.vivo.product.model PD2031
    setprop ro.product.model PD2031
    setprop ro.product.board k6853v1_64_6360

on boot
    exec u:r:recovery:s0 root root -- /system/bin/vts_app_recovery --update
```

**添加文件：**
- `recovery/root/system/bin/vts_app_recovery` - 从原厂recovery提取的触控固件更新程序

---

## 第三阶段：USB连接修复

### 3.1 问题描述

进入 TWRP 主界面前有短暂的 ADB 连接，但进入主界面后 ADB 断开，电脑无法识别设备。

### 3.2 原因分析

设备使用 USB configfs 模式，TWRP 进入主界面后 USB 配置被重置，需要正确配置 configfs 参数。

### 3.3 解决方案

**文件：** `init.recovery.mt6853.rc`

```rc
on init
    setprop sys.usb.configfs 1
    setprop sys.usb.ffs.aio_compat 1
```

---

## 第四阶段：重启循环修复

### 4.1 问题描述

设备进入TWRP后，一旦在Recovery内点击重启进入Recovery后，重启只能进入TWRP，形成重启循环。

### 4.2 原因分析

起初为了修复adb reboot recovery无效果的问题，我在init拦截了reboot recovery的请求并且插入执行了一个脚本(/system/bin/rebootrecovery.sh)，该脚本会向misc分区写入重启进rec的指令。   
可是我没有写清除指令的脚本，就导致了这个问题，手机重启后持续引导至recovery。

### 4.3 解决方案

**脚本：** `recovery/root/system/bin/clear_bcb.sh`

```bash
dd if=/dev/zero of=/dev/block/by-name/misc bs=512 count=1
```

**触发：** `init.recovery.mt6853.rc`

```rc
on post-fs
    exec u:r:recovery:s0 root root -- /system/bin/clear_bcb.sh
```

### 4.4 拦截reboot recovery命令

**脚本：** `recovery/root/system/bin/rebootrecovery.sh`

```bash
MISC_PARTITION="/dev/block/by-name/misc"

echo -n "boot-recovery" > /tmp/bcb_command
dd if=/dev/zero bs=2048 count=1 2>/dev/null | dd of=$MISC_PARTITION bs=2048 count=1 2>/dev/null
dd if=/tmp/bcb_command of=$MISC_PARTITION bs=1 count=13 2>/dev/null
sync
# 然后reboot
/system/bin/reboot
```

**触发：**

```rc
on property:sys.powerctl=reboot,recovery
    exec u:r:recovery:s0 root root -- /system/bin/rebootrecovery.sh
```

---

## 第五阶段：TEE/Trustonic 环境配置

### 5.1 问题描述

FBE解密需要Trustonic TEE支持，但TEE daemon无法启动。

### 5.2 解决方案

#### 5.2.1 Persist分区挂载

```rc
on post-fs
    wait /dev/block/by-name/persist
    mount ext4 /dev/block/by-name/persist /mnt/vendor/persist noatime

    chown system system /mnt/vendor/persist
    chmod 0771 /mnt/vendor/persist
    mkdir /mnt/vendor/persist/mcRegistry 0771 system system
```

#### 5.2.2 TEE设备权限

```rc
on post-fs
    chmod 0666 /dev/mobicore
    chmod 0666 /dev/mobicore-user
    chmod 0660 /dev/t-base-tui
    chmod 0660 /dev/rpmb0
    chown system system /dev/mobicore
    chown system system /dev/mobicore-user
    chown system system /dev/t-base-tui
    chown system system /dev/rpmb0
```

#### 5.2.3 MobiCore Daemon服务

```rc
service mobicore /vendor/bin/mcDriverDaemon \
    --P1 /mnt/vendor/persist/mcRegistry \
    -r /vendor/app/mcRegistry/06090000000000000000000000000000.drbin \
    -r /vendor/app/mcRegistry/020f0000000000000000000000000000.drbin \
    -r /vendor/app/mcRegistry/05120000000000000000000000000000.drbin \
    -r /vendor/app/mcRegistry/05070000000000000000000000000000.drbin \
    -r /vendor/app/mcRegistry/030b0000000000000000000000000000.drbin \
    -r /vendor/app/mcRegistry/030c0000000000000000000000000000.drbin
    disabled
    seclabel u:r:recovery:s0
```

注: init.recovery.platform.rc和init.recovery.mt6853.rc内都有这段配置，理论上来讲保留1个，另外一个可以注释掉，但是我秉持着能用就不动的原则还是留下了。

#### 5.2.4 添加Trustlets

从原厂rec提取以下trustlet文件到 `/vendor/app/mcRegistry/`:
- `06090000000000000000000000000000.drbin` - Keymaster TA
- `020f0000000000000000000000000000.drbin` - Gatekeeper TA
- `05120000000000000000000000000000.drbin`
- `05070000000000000000000000000000.drbin`
- `030b0000000000000000000000000000.drbin`
- `030c0000000000000000000000000000.drbin`

---

## 第六阶段：AVB Footer 与 boot_patchlevel 修复

### 6.1 问题描述

TEE 解密失败，日志显示 `boot_patchlevel = 20300101`（默认值），而原厂应该是 `20190606`。

FBE 密钥在原厂系统创建时绑定了 `boot_patchlevel = 20190606`，TEE 验证时发现不匹配导致解密失败。

### 6.2 原因分析

```
验证流程:
Bootloader ─── 读取 AVB footer ─── 验证签名 ───┬── 原厂签名: 传递 20190606 给 TEE ─→ ✓ 验证通过
                                               └── 错误签名: 传递 20300101 给 TEE ─→ ✗ 验证失败
```

TWRP 使用非原厂密钥签名，bootloader 不信任，因此向 TEE 传递默认值 `20300101`。

### 6.3 发现过程

通过分析 magiskboot 重打包后的原厂 recovery，发现：
- 原厂recovery打开adb功能后，检查dmesg发现tee可以正常返回20190606。
- 我想直接修改twrp源码让他强制返回20190606，但是理论上这是不可能的。因为boot_patchlevel 在 kernel 启动前就已经写入 TEE 安全内存。
- 我突然想起来，原厂的recovery应该是没有adb功能的，我是通过magiskboot解包修改prop.default文件后强开的adb权限
- 问题是修改了文件再重打包，那么 AVB 签名本来应该失效了。
- 经过分析发现，magiskboot 保留了完整的原厂 AVB footer（包括 Vivo 公钥）！
- 所以可得 vivo 的 Bootloader **只检查公钥匹配，不真正验证 Hash**
- 因此可以用原厂 AVB footer + TWRP 内容创建混合镜像

### 6.4 解决方案

创建 `make_hybrid.py` 脚本：

脚本一共做了4件事
1. 从原厂 recovery 提取 Vivo AVB footer (保存到 vivo_avb_footer.bin)
2. 从 TWRP recovery.img 提取内容（去除 AVB footer）
3. 将 Vivo AVB footer 附加到 TWRP 内容后
4. 输出混合镜像

**使用方法：**
```bash
# 编译后运行
python3 device/vivo/k6853v1_64_6360/make_hybrid.py
```

### 6.5 结果

混合镜像刷入后，TEE 正确读取 `boot_patchlevel = 20190606`，解密验证通过。

---

## 第七阶段：SDK版本修复

### 7.1 问题描述

Keymaster服务因SDK版本不匹配而拒绝工作。设备原厂是Android 10 (SDK 29)，但TWRP基于更高版本。

### 7.2 解决方案

可以使用resetprop强行修改ro的prop。

```rc
on post-fs
    exec u:r:recovery:s0 root root -- /system/bin/resetprop ro.build.version.sdk 29
    exec u:r:recovery:s0 root root -- /system/bin/resetprop ro.system.build.version.sdk 29
    exec u:r:recovery:s0 root root -- /system/bin/resetprop ro.vendor.build.version.sdk 29
    exec u:r:recovery:s0 root root -- /system/bin/resetprop ro.product.build.version.sdk 29
    exec u:r:recovery:s0 root root -- /system/bin/resetprop ro.odm.build.version.sdk 29
    exec u:r:recovery:s0 root root -- /system/bin/resetprop ro.system_ext.build.version.sdk 29
```

---

## 第八阶段：Keymaster/Gatekeeper服务配置

### 8.1 服务定义

```rc
service vendor.keymaster-4-0-trustonic /vendor/bin/hw/android.hardware.keymaster@4.0-service.trustonic
    disabled
    user root
    group root drmrpc
    seclabel u:r:recovery:s0

service gatekeeper-1-0 /vendor/bin/android.hardware.gatekeeper@1.0-service
    disabled
    user root
    group root
    seclabel u:r:recovery:s0

service wait_for_keymaster /system/bin/wait_for_keymaster
    disabled
    user root
    seclabel u:r:recovery:s0
```

### 8.2 服务启动顺序

```rc
on property:recovery.service=1
    stop keystore2
    start vendor.keymaster-4-0-trustonic
    start gatekeeper-1-0
    exec_start wait_for_keymaster
    start guardianangle
```

**启动顺序必须是：** mobicore → keymaster → gatekeeper → wait_for_keymaster , 错了就炸解密。

---

## 第九阶段：FBE解密核心修复 (耗时最长的一个。。。)

### 9.1 Keymaster HIDL 4.0 重写

**问题：** 

经过上面的修改后，解密仍然失败，有 `signal: 6` (SIGABRT 崩溃)且崩溃非常快，几乎在解密开始时就发生了。   
在recovery.log里观察到 `Is_Encrypted Is_Decrypted` 同时存在, 这表示 **DE 已解密但 CE 未解密**。   
最后发现TWRP原有的Keymaster实现与Trustonic TEE的HIDL 4.0接口不兼容。   
这里是一个坑，如果我选择安卓10的版本构建的话就不会出这种事，但好巧不巧我用的安卓12....   
[system_vold](https://android.googlesource.com/platform/system/vold/+/refs/tags/android-10.0.0_r47) 这是安卓10的实现。有兴趣的可以看看。

**文件：** `system/vold/Keymaster.cpp`, `system/vold/Keymaster.h`

**主要修改：**
```cpp
#include <android/hardware/keymaster/4.0/IKeymasterDevice.h>
using ::android::hardware::keymaster::V4_0::IKeymasterDevice;

class Keymaster {
public:
    Keymaster();
    bool isValid() { return mDevice != nullptr; }
    KeymasterOperation begin(km::KeyPurpose purpose,
                            const km::AuthorizationSet& inParams,
                            const std::string& blob);
private:
    sp<IKeymasterDevice> mDevice;
};
```

### 9.2 KeyParameterValue 类型转换修复

**问题：** `convertToHidl()` 在处理不同tag类型时会导致Recovery崩溃。

**解决方案：** 根据tag类型正确设置union成员

```cpp
switch (typeFromTag(param.tag)) {
    case TagType::ENUM:
    case TagType::ENUM_REP:
        hParam.f.algorithm = static_cast<Algorithm>(param.f.integer);
        break;
    case TagType::UINT:
    case TagType::UINT_REP:
        hParam.f.integer = param.f.integer;
        break;
    case TagType::ULONG:
    case TagType::ULONG_REP:
        hParam.f.longInteger = param.f.longInteger;
        break;
    case TagType::DATE:
        hParam.f.dateTime = param.f.dateTime;
        break;
    case TagType::BOOL:
        hParam.f.boolValue = param.f.boolValue;
        break;
    case TagType::BYTES:
        hParam.blob = kmBlob2hidlVec(param.blob);
        break;
}
```

### 9.3 FsCrypt.cpp 空指针修复

**问题：** `GetEntryForMountPoint()` 返回null后代码尝试访问成员，导致Recovery崩溃。

**文件：** `system/vold/FsCrypt.cpp:489`

```cpp
// 修复前
GetEntryForMountPoint(&fstab_default, DATA_MNT_POINT)->fs_mgr_flags.wrapped_key = ...

// 修复后
auto* entry = GetEntryForMountPoint(&fstab_default, DATA_MNT_POINT);
if (entry) entry->fs_mgr_flags.wrapped_key = ...
```

### 9.4 ReadDefaultFstab 失败回退

**问题：** Recovery模式下 `/vendor` 未挂载，`ReadDefaultFstab()` 失败，导致无法解密。

**解决方案：** 添加硬编码回退

```cpp
if (!ReadDefaultFstab(&fstab_default)) {
    // 硬编码回退 - Vivo Y73S使用 aes-256-xts:aes-256-cts v1
    options->version = 1;
    options->contents_mode = 1;  // FSCRYPT_MODE_AES_256_XTS
    options->filenames_mode = 4; // FSCRYPT_MODE_AES_256_CTS
    options->flags = 0;
    options->use_hw_wrapped_key = false;
    return true;
}
```

### 9.5 强制使用 Legacy Keyring

**问题：** `isFsKeyringSupported()` 检测不准确，导致使用内核不支持的ioctl，导致无法解密。

**文件：** `system/vold/KeyUtil.cpp`

```cpp
switch (options.version) {
    case 1:
        policy->key_raw_ref = generateKeyRef((const uint8_t*)key.data(), key.size());
        // TWRP修复: 对v1策略强制使用legacy keyring
        return installKeyLegacy(key, policy->key_raw_ref);
        break;
}
```

### 9.6 自动创建 fscrypt Keyring

**问题：** Recovery模式下 "fscrypt" keyring不存在。

**解决方案：** 写一个

```cpp
static bool fscryptKeyring(key_serial_t* device_keyring) {
    *device_keyring = keyctl_search(KEY_SPEC_SESSION_KEYRING, "keyring", "fscrypt", 0);
    if (*device_keyring == -1) {
        // 创建keyring
        *device_keyring = add_key("keyring", "fscrypt", NULL, 0, KEY_SPEC_SESSION_KEYRING);
        if (*device_keyring == -1) {
            return false;
        }
    }
    return true;
}
```

---

## 第十阶段：MTP文件传输修复

### 10.1 问题描述

TWRP中启用MTP后，电脑无法识别设备进行文件传输。

### 10.2 MTP FunctionFS配置

```rc
on boot
    mkdir /config/usb_gadget/g1/functions/ffs.mtp 0770 shell shell
    mkdir /dev/usb-ffs/mtp 0770 shell shell
    mount functionfs mtp /dev/usb-ffs/mtp rmode=0770,fmode=0660,uid=2000,gid=2000
```

### 10.3 USB Gadget 模式配置

```rc
on property:sys.usb.config=mtp && property:sys.usb.configfs=1 && property:sys.usb.ffs.mtp.ready=1
    write /config/usb_gadget/g1/configs/b.1/strings/0x409/configuration "mtp"
    write /config/usb_gadget/g1/idProduct 0x4ee1
    symlink /config/usb_gadget/g1/functions/ffs.mtp /config/usb_gadget/g1/configs/b.1/f1
    write /config/usb_gadget/g1/UDC ${sys.usb.controller}
    setprop sys.usb.state ${sys.usb.config}

on property:sys.usb.config=mtp,adb && property:sys.usb.configfs=1 && property:sys.usb.ffs.mtp.ready=1 && property:sys.usb.ffs.ready=1
    write /config/usb_gadget/g1/configs/b.1/strings/0x409/configuration "mtp_adb"
    write /config/usb_gadget/g1/idProduct 0x4ee2
    symlink /config/usb_gadget/g1/functions/ffs.mtp /config/usb_gadget/g1/configs/b.1/f1
    symlink /config/usb_gadget/g1/functions/ffs.adb /config/usb_gadget/g1/configs/b.1/f2
    write /config/usb_gadget/g1/UDC ${sys.usb.controller}
    setprop sys.usb.state ${sys.usb.config}
```

### 10.4 USB Config切换修复

**问题：** `on property:sys.usb.config=none` 触发器会阻止MTP切换，导致MTP功能无法使用。

**解决方案：** 注释掉该触发器

```rc
# 在原本的init里注释掉这个，这段会阻止MTP切换
# on property:sys.usb.config=none
#     setprop sys.usb.config adb
```

---

## 修改文件汇总

| 文件 | 修改内容 |
|------|----------|
| `system/vold/Keymaster.cpp` | 重写HIDL 4.0实现 |
| `system/vold/Keymaster.h` | 重写头文件 |
| `system/vold/KeyStorage.cpp` | 添加debug和错误处理 |
| `system/vold/KeyUtil.cpp` | 强制legacy keyring，自动创建fscrypt keyring |
| `system/vold/FsCrypt.cpp` | 空指针修复，硬编码回退选项 |
| `device/.../init.recovery.mt6853.rc` | 完整的init配置 |
| `device/.../recovery.fstab` | 分区表 |
| `device/.../BoardConfig.mk` | 编译配置 |

---

## 添加的二进制文件

| 文件 | 来源 | 用途 |
|------|------|------|
| `vts_app_recovery` | 原厂recovery | 触控固件更新 |
| `clear_bcb.sh` | 自编写 | 清除BCB防止重启循环 |
| `rebootrecovery.sh` | 自编写 | 拦截recovery重启命令 |
| `wait_for_keymaster` | 原厂 | 等待keymaster服务就绪 |
| `guardianangle` | 原厂 | 安全守护进程 |
| `mcDriverDaemon` | 原厂 | Trustonic TEE daemon |
| `keymaster@4.0-service.trustonic` | 原厂 | Keymaster HAL服务 |
| `gatekeeper@1.0-service` | 原厂 | Gatekeeper HAL服务 |
| `*.drbin`, `*.tlbin` | 原厂 | Trustonic trustlets |
| `make_hybrid.py` | 自编写 | 创建混合镜像(TWRP+Vivo AVB footer) |
| `vivo_avb_footer.bin` | 原厂recovery提取 | Vivo AVB签名footer |

---

## 完成日期

2026年1月2日——1月6日

---

## 第十一阶段：密码解密软重启修复 (Bug 2)

### 问题描述
输入用户密码后，TWRP 发生软重启，无法完成解密。

### 根因分析
Keystore blob 偏移量错误：
- 最初错误估计是 offset 44
- 实际正确值是 **offset 40**

### Keystore Blob 格式 (blobv3)
```
Offset 0-3:   Header (version=3, type=4, flags=8, info=0)
Offset 4-38:  Padding (35 bytes of zeros)
Offset 39:    Length byte (0xe0 = 224)
Offset 40+:   Keymaster blob (224 bytes)
```

### 调试方法
使用 `getKeyCharacteristics()` 测试不同偏移量：
```
offset 0:  error -26 (INVALID_KEY_BLOB)
offset 4:  error -26 (INVALID_KEY_BLOB)
offset 40: error 0 (SUCCESS) ← 正确偏移量
offset 44: error -33 (KEY_REQUIRES_UPGRADE)
```

### 解决方案
修改 `system/vold/Decrypt.cpp`：
```cpp
size_t best_offset = 40; //直接硬编码进去
if (key_blob.size() > best_offset) {
    key_blob = key_blob.substr(best_offset);
}
```

---

## 第十二阶段：Magisk 安装兼容性修复 (Bug 3)

### 问题描述
在 TWRP 中刷入 Magisk 时报错：
```
! Unable to extract boot image
openat '/dev/block/by-name/boot': : Permission denied
```

### 根因分析
`magiskboot` 工具无法直接打开块设备，即使 SELinux 为 Permissive。

### 解决方案
修改 `bootable/recovery/twrpinstall/twinstall.cpp`，在安装 zip 时：

**预处理**：
1. 读取 `/dev/block/by-name/boot` 原始符号链接目标
2. 将 boot 分区内容拷贝到 `/tmp/twrp_boot.img`
3. 保存原始副本到 `/tmp/twrp_boot_orig.img`
4. 重定向符号链接到临时文件

**后处理**：
1. 恢复原始符号链接
2. 比较临时文件与原始副本
3. 仅当文件被修改时，才写回到 boot 分区
4. 清理临时文件

---

## 第十三阶段：TWRP App 安装崩溃修复 (Bug 4)

### 问题描述
选择"安装 TWRP App"时，设备发生 SIGSEGV 崩溃：
```
I:Installing app to '/system_root/system/priv-app/twrpapp'
libc: Fatal signal 11 (SIGSEGV), code 1 (SEGV_MAPERR), fault addr 0xffffffffffffffe0
```

### 根因分析
TWRP 尝试将 app 安装到动态分区 system，挂载失败后访问空指针导致崩溃。

### 解决方案

安装的时候不要选"安装为系统应用"。

---

## 第十四阶段：启动红色错误消息修复 (Bug 5)

### 问题描述
TWRP 启动时显示大量红色错误消息，很难看：
```
Failed to mount '/vendor' (Permission denied)
Failed to mount '/system_root' (Device or resource busy)
Failed to mount '/persist' (Device or resource busy)
```

### 根因分析
1. `/vendor` 和 `/system_root`：动态分区在早期启动阶段尚未映射
2. `/persist`：已在 init 脚本中挂载到 `/mnt/vendor/persist`

### 解决方案

#### 1. 修改 partition.cpp
```cpp
// Skip error display for dynamic partitions
if (!Removable && Display_Error &&
    Mount_Point != "/vendor" && Mount_Point != "/system_root" && Mount_Point != "/persist")
    gui_msg(...);
```

#### 2. 修复 recovery.fstab
- 移除 `first_stage_mount` 标志，TWRP 不识别这个
- 将挂载点从 `/mnt/vendor/xxx` 改为 `/xxx`
- 更新外部存储设备路径

#### 3. 外部存储路径
```
SD卡：/devices/platform/11230000.msdc*
USB OTG：/devices/platform/11200000.usb_xhci*
```
---

## 第十五阶段：ADB Sideload 取消卡死修复 (Bug 1)

### 问题描述
取消 ADB sideload 操作后，TWRP 无限期挂起，无法返回主界面。

### 根因分析
`adb_install.cpp` 中的 `SetUsbConfig()` 函数调用 `WaitForProperty()` 等待 USB 状态变化，但当取消 sideload 时，USB 状态可能不会改变，导致永久阻塞。

### 解决方案
在 `WaitForProperty()` 调用中添加 5 秒超时：

**文件:** `bootable/recovery/twrpinstall/adb_install.cpp`

```cpp
#include <chrono>

static bool SetUsbConfig(const std::string& state) {
    android::base::SetProperty("sys.usb.config", state);
    return android::base::WaitForProperty("sys.usb.state", state, std::chrono::seconds(5));
}
```

**补丁文件:** `patches/bootable_recovery/0003-Fix-adb-sideload-5s-timeout.patch`

---

## 第十六阶段：支持橙狐rec & 设备显示名称优化

### 修改内容
将 TWRP/OrangeFox 界面中的设备信息改为更友好的显示：

| 项目 | 修改前 | 修改后 |
|------|--------|--------|
| Platform | k6853v1_64_6360 | mt6853 |
| Device | k6853v1_64_6360 | PD2031 |

### 修改文件
**TWRP:** `device/vivo/k6853v1_64_6360/omni_k6853v1_64_6360.mk`
```makefile
PRODUCT_MODEL := PD2031
```

**OrangeFox:** `device/vivo/k6853v1_64_6360/omni_k6853v1_64_6360.mk`
```makefile
PRODUCT_MODEL := PD2031
FOX_DEVICE_MODEL := PD2031
PRODUCT_PLATFORM := mt6853
```

---

## 第十七阶段：分区备份与刷入功能增强

### 问题描述
默认只能备份 boot, cache, data, super 分区，无法备份其他重要分区（如 nvram, proinfo 等）。
也无法单独刷入 system, vendor 等逻辑分区。

### 解决方案
在 `recovery.fstab` 中为所有分区添加 `backup=1` 和 `flashimg=1` 标志。

### 新增可备份分区

#### ext4 可挂载分区 (14个)
| 分区 | 说明 |
|------|------|
| oem | OEM 定制分区 |
| vgc | Vivo 游戏中心 |
| system | 系统分区 |
| system_ext | 系统扩展分区 |
| vendor | 厂商分区 |
| product | 产品分区 |
| metadata | 元数据分区 |
| data | 用户数据分区 |
| cache | 缓存分区 |
| protect_f | 保护分区 1 |
| protect_s | 保护分区 2 |
| nvdata | NV 数据 |
| nvcfg | NV 配置 |
| persist | 持久化数据 |

#### emmc 原始分区 (40+)
| 分区 | 说明 | 重要性 |
|------|------|--------|
| nvram | 基带 NVRAM | 极高 - 包含 IMEI |
| proinfo | 设备信息 | 高 |
| bootloader/lk | 引导加载器 | 高 |
| boot | 内核 | 高 |
| recovery | Recovery | 高 |
| vbmeta* | AVB 验证 | 中 |
| tee1/tee2 | TEE 固件 | 高 |
| dtbo/odmdtbo | 设备树 | 中 |
| md1img/md1dsp | 基带固件 | 高 |
| scp1/scp2 | 协处理器固件 | 中 |
| sspm_1/sspm_2 | 安全子系统 | 中 |
| gz1/gz2 | GenieZone 固件 | 中 |

### recovery.fstab 示例
```
/system_root    ext4    system      flags=display=system;logical;backup=1;wipeingui;flashimg=1
/vendor         ext4    vendor      flags=display=vendor;logical;backup=1;wipeingui;flashimg=1
/nvram          emmc    /dev/block/by-name/nvram    flags=display=nvram;backup=1
/bootloader     emmc    /dev/block/by-name/lk       flags=display=bootloader;backup=1;flashimg=1
```

---

## OrangeFox Recovery 适配

### 源码位置
`~/fox_12.1/`

### 编译命令
```bash
cd ~/fox_12.1
source build/envsetup.sh
lunch omni_k6853v1_64_6360-eng
mka recoveryimage
python3 device/vivo/k6853v1_64_6360/make_hybrid_fox.py
```

### OrangeFox 特有配置
在 `omni_k6853v1_64_6360.mk` 中添加：
```makefile
# OrangeFox specific
FOX_DEVICE_MODEL := PD2031
PRODUCT_PLATFORM := mt6853
```
---

## 第十八阶段：自动安全补丁级别检测 (Auto Patch Level)

### 问题描述

FBE 解密需要 `ro.build.version.security_patch` 属性与系统创建密钥时的值匹配。之前使用硬编码的 `PLATFORM_SECURITY_PATCH` 值，如果用户系统升级后安全补丁日期变化，则无法解密。

### 原因分析

Keymaster HAL 从系统属性 `ro.build.version.security_patch` 读取安全补丁级别：

```cpp
// hardware/interfaces/keymaster/4.0/support/keymaster_utils.cpp
constexpr char kPlatformPatchlevelProp[] = "ro.build.version.security_patch";

uint32_t getOsPatchlevel() {
    std::string patchlevel = wait_and_get_property(kPlatformPatchlevelProp);
    return getOsPatchlevel(patchlevel.c_str());
}
```

如果此属性值与密钥创建时不一致，TEE 将拒绝解密操作。

### 解决方案

创建自动检测脚本，在 keymaster 启动前从系统分区读取真实的安全补丁级别。

**脚本:** `recovery/root/system/bin/auto_patchlevel.sh` 此脚本开机时优先启动，可能会导致开机变慢。

**Init 配置:** `init.recovery.mt6853.rc`

```rc
on post-fs
    exec u:r:recovery:s0 root root -- /system/bin/auto_patchlevel.sh
```

### 细节

1. **读取顺序优先级:**
   - 已挂载的 `/system_root/system/build.prop`
   - 动态分区 `/dev/block/mapper/system_a`
   - 动态分区 `/dev/block/mapper/system`
   - 传统分区 `/dev/block/by-name/system`

2. **设置的属性:**
   - `ro.build.version.security_patch`
   - `ro.vendor.build.security_patch` (实际不应该设置，因为vivo y73s的vendor日期都没变过。)
   - `ro.system.build.version.security_patch`

3. **执行时机:**
   - 在 `on post-fs` 阶段
   - 在 SDK 版本修复之后
   - 在 keymaster 服务启动之前

### 优势

- **通用性**: 无需为每个安全补丁日期生成不同的镜像
- **自动化**: Recovery 启动时自动检测，无需用户干预
- **兼容性**: 支持系统升级后继续正常解密

### 实际实现修复 (v1)

在实际测试中发现多个问题需要修复：

#### 问题 1: 日志污染属性值
**现象:** `ro.build.version.security_patch=[AutoPatchLevel] Searching...`

**原因:** `log_info()` 输出到 stdout，被 `$()` 命令替换捕获

**解决:** 日志输出到 stderr (`>&2`) 和直接写入 `/tmp/recovery.log`

#### 问题 2: Super 分区搜索失败
**原因:** System 分区可能不在 super 分区开头，50MB 搜索范围不够

**解决 (v1):**
```bash
# 方法1: grep -a 搜索整个分区 (快速)
grep -a -o "ro.build.version.security_patch=[0-9-]*" "$super_dev"

# 方法2: 分段搜索 200MB (fallback)
for skip in 0 50 100 150; do
    dd if="$super_dev" bs=1M skip=$skip count=50 | strings | grep ...
done
```

#### 问题 3: Vendor 安全补丁不应修改
**说明:** Vivo Y73S 的 vendor 分区从出厂至今未更新过，始终为 `2020-07-05`。

**解决:** 不修改 `ro.vendor.build.security_patch`

### 添加的文件

| 文件 | 用途 |
|------|------|
| `recovery/root/system/bin/auto_patchlevel.sh` | 自动检测并设置安全补丁级别 (v2.2) |

---

## 第十九阶段：大文件 zip 安装支持 (Bug 7)

### 问题描述

安装某些大型zip刷机包时报错 "Zip 文件已损坏"，但该 zip 文件完全正常。其他zip(如 Magisk) 可以正常安装。

### 根因分析

可能是奇奇怪怪的压缩格式导致的。

### 解决方案

unzip使用7zzs

### 补丁文件

`patches/bootable_recovery/0004-Large-zip-file-support.patch`
`patches/bootable_recovery/0006-Zip64-fallback-and-7zzs-ramdisk.patch`

---

## 第二十阶段：文件系统分区镜像刷入修复 (Bug 8)

### 问题描述

尝试刷入 system.img 到 system 分区时报错：
```
E:Cannot flash images to file systems
```

即使 recovery.fstab 中已设置 `flashimg=1` 标志。

### 根因分析

`partition.cpp` 中 `Flash_Image()` 函数的检查逻辑顺序错误：

```cpp
// 原代码
if (Backup_Method == BM_FILES) {           // ext4 分区走这里
    LOGERR("Cannot flash images to file systems\n");
    return false;                          // 直接返回，不检查 Can_Flash_Img
} else if (!Can_Flash_Img) {
    ...
}
```

对于 ext4/f2fs 分区，`Backup_Method = BM_FILES`（文件备份模式），代码首先检查这个条件就直接报错，根本没机会检查 `Can_Flash_Img` 标志。

### 解决方案

修改检查顺序：先检查 `Can_Flash_Img`，如果允许刷入镜像，则使用 dd/sparse 方式。

**文件:** `bootable/recovery/partition.cpp`

```cpp
bool TWPartition::Flash_Image(PartitionSettings *part_settings) {
    // ...

    // 先检查是否允许刷入镜像
    if (!Can_Flash_Img) {
        LOGERR("Cannot flash images to partitions %s\n", Display_Name.c_str());
        return false;
    }

    // 大小检查...

    // 对于文件系统分区 (BM_FILES) 或 emmc 分区 (BM_DD)，都使用 dd/sparse 方式刷入
    if (Backup_Method == BM_FILES || Backup_Method == BM_DD) {
        if (!part_settings->adbbackup) {
            if (Is_Sparse_Image(full_filename)) {
                return Flash_Sparse_Image(full_filename);
            }
        }
        return Raw_Read_Write(part_settings);
    }
    // ...
}
```

### 补丁文件

`patches/bootable_recovery/0005-Allow-flash-image-to-filesystem-partitions.patch`

---

## 最终补丁文件列表

```
patches/
├── apply-patches.sh              
├── revert-patches.sh             
├── system_vold/                  # Vold FBE 解密补丁
│   ├── 0001-Keymaster-HIDL-4.0-for-Trustonic-TEE.patch
│   ├── 0002-KeyStorage-add-debug-logging.patch
│   ├── 0003-KeyUtil-force-legacy-keyring.patch
│   ├── 0004-FsCrypt-hardcoded-options-and-fixes.patch
│   ├── 0005-Decrypt-add-debug-logging.patch
│   └── 0006-Direct-Keymaster-HIDL-for-synthetic-password.patch
└── bootable_recovery/            # Recovery 功能补丁
    ├── 0001-Magisk-boot-partition-compatibility.patch
    ├── 0002-Suppress-mount-errors-for-dynamic-partitions.patch
    ├── 0003-Fix-adb-sideload-5s-timeout.patch
    ├── 0004-Large-zip-file-support.patch
    ├── 0005-Allow-flash-image-to-filesystem-partitions.patch
    └── 0006-Zip64-fallback-and-7zzs-ramdisk.patch
```

---

## 最终功能状态

| 功能 | 状态 | 备注 |
|------|------|------|
| 触摸屏 | ✅ 正常 | |
| ADB 连接 | ✅ 正常 | |
| FBE 解密 (默认密码) | ✅ 正常 | |
| FBE 解密 (用户密码) | ✅ 正常 | 自动检测安全补丁日期，但是锁屏密码还是得你自己填 |
| MTP 传输 | ✅ 正常 | |
| 文件浏览 | ✅ 正常 | |
| Magisk 安装 | ✅ 正常 | |
| OTA 包安装 | ✅ 正常 | |
| 分区镜像刷入 | ⚠️ 待测试 | 理论上支持 system/vendor 等单独刷入 |
| ADB Sideload | ✅ 正常 | 取消操作不再卡死 |
| 分区备份 | ✅ 正常 | 支持 50+ 分区 |
| 分区刷入 | ✅ 正常 | 支持单独刷入逻辑分区 |
| TWRP App 安装 | ⚠️ 已禁用 | 动态分区不支持 |
| 外部存储 (SD卡) | ❓ 待测试 | |
| 外部存储 (USB OTG) | ❓ 待测试 | |

---

## 最后更新

2026年1月11日

待更新。。。。。