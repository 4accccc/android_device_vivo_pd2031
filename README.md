# TeamWin Recovery Project device tree for vivo Y73s (PD2031 k6853v1_64_6360)
![vivo Y73s](https://i.postimg.cc/MGZdvGQr/image.png "vivo Y73s")


| Feature                 | Specification                                                        |
| :---------------------- | :--------------------------------------------------------------------|
| CPU                     | Octa-core (2x 2.0 GHz Cortex-A76 & 6x 2.0 GHz Cortex-A55)            |
| Chipset                 | MediaTek Dimensity 720 (MT6853) 7nm                                  |
| GPU                     | Mali-G57 MC3                                                         |
| Memory                  | 6 GB / 8 GB                                                          |
| Shipped Android Version | Android 10, Funtouch OS 10.5                                         |
| Storage                 | 128 GB / 256 GB                                                      |
| Battery                 | 4100 mAh (non-removable)                                             |
| Display                 | 1080x2400, 6.44", 409 PPI                                            |
| Rear Camera             | 48 MP, LED flash                                                     |
| Front Camera            | 16 MP                                                                |
| Release Date            | Oct. 10, 2020                                                        |

## Compatible Devices

- vivo Y73s

- **Codename**: PD2031
- **Platform**: MediaTek MT6853 (Dimensity 720)
- **Android Version**: 10
- **Partition Layout**: System-as-root, non-A/B, Dynamic Partitions (super)
- **Encryption**: FBE (File-Based Encryption) with wrappedkey, aes-256-xts

## Compatible Recovery builds

- TeamWin Recovery Project (branch twrp-12.1)
- OrangeFox Recovery (branch fox_12.1)

## Notice!

You may find it will take a **loooooong** time to boot into recovery and that is normal.    
Because in order to decrypt your data, I have to know your Android Security Patch level and it seems that the only way to get that is to search all over the super partition.   

If you don't want to wait for a long time, you can delete /recovery/root/system/bin/auto_patchlevel.sh and that will make you get into recovery faster for sure. BUT once your system's security patch level changed, you'll need to change the date in BoardConfig.mk, build the whole recovery again and then flash it back to your phone.

## 注意！

你可能会发现启动到recovery需要的时间有点长，这很正常。为了解密你的数据，我必须知道你的Android安全补丁级别，而且貌似唯一的方法就是在整个super分区中搜索。   
如果你不想等待很长时间，你可以把/recovery/root/system/bin/auto_patchlevel.sh给删了，这肯定会让你更快地进rec。但是，一旦系统的Android安全补丁变了，就要在BoardConfig.mk中更改日期，再次构建整个recovery镜像，然后将其刷回你的手机。

## 已解决项目

* 触屏
* 亮度
* 挂载分区
* USB调试
* Data分区解密
* MTP

<img src="https://raw.githubusercontent.com/4accccc/randomstuffs/refs/heads/main/MainPage.png" width="15%" alt="主页"><img src="https://raw.githubusercontent.com/4accccc/randomstuffs/refs/heads/main/Decrypted_Data.png" width="15%" alt="解密Data示例">

## Bugs   
   
### 已解决：
* ~进入adb sideload后无法点击取消按钮退出。~

解决方案: 修改twrp源码加入5秒超时，点击取消按钮后5秒强制退出。

* ~如果有锁屏密码，在输入密码尝试解密时会直接软重启。~

解决方案: 应该是除了重写Keymaster.cpp以外最复杂的，这里也解释一下为什么要重写，TWRP12.1默认走的是android 11以上的AIDL(Keystore2)架构，需要用安卓10的keymaster hidl直接重写twrp原版自带的aidl。(这个问题主要涉及Decrypt.cpp)

* 有的时候在文件管理内无法修改用户数据内某些文件的文件名(mv命令报错)，多次尝试改名会触发一次软重启，然后提示需要输入锁屏密码解密data(即使没有锁屏密码)，不输入密码直接去查看用户数据仍是解密的。再次尝试修改用户数据内文件名成功。

解决方案: 同上。 

* ~可以提取boot分区，但是magisk安装报错无法unpack boot，原因未知。~

解决方案：magisk无法直接打开block设备导致无法读取boot分区。现在加入刷前预处理:复制boot到临时文件→保存原始副本→重定向符号链接，刷完后处理:恢复符号链接→比较文件是否被修改→修改了才写回

* ~安装twrp应用为系统应用时软重启~

解决方案: 去掉安装为系统应用的勾。

### 更多请查看[DEVELOPMENT_LOG.md](https://github.com/4accccc/android_device_vivo_pd2031/blob/twrp-12.1/DEVELOPMENT_LOG.md)

## 如何构建？
最好科学上网。如果有哪步运行出错了别开issue问我，烦人。问AI就行了   
先安装依赖
~~~
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev git
~~~

[然后跟着这个教程装repo](https://mirrors.tuna.tsinghua.edu.cn/help/git-repo/)，repo装好了过后，在你的用户目录   

~~~
mkdir twrp
cd twrp
export ALLOW_MISSING_DEPENDENCIES=true
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
repo sync -j$(nproc)   # $(nproc)是最大线程，你也可以改小点比如4,2啥的
mkdir -p device/vivo
cd device/vivo
git clone https://github.com/4accccc/android_device_vivo_pd2031.git k6853v1_64_6360
cd ../..
python3 device/vivo/k6853v1_64_6360/patches/apply-patches.sh
# 一定要执行！不然build出来的twrp无法解密分区！
~~~
如果patches不能合并，请手动跟着patch文件改源码，很简单。由于vold解密部分修改过多，为了方便，你可以把整个system/vold里面的东西换成[这里面的](https://github.com/4accccc/android_system_vold)。
~~~
source build/envsetup.sh
lunch omni_k6853v1_64_6360-eng
mka recoveryimage
python3 device/vivo/k6853v1_64_6360/make_hybrid.py
# 一定要运行！vivo会验证avb footer数据，校验不过tee会返回一个错误的patchlevel(20300101)，无法解密data。
# 这个脚本能用vivo原厂avb footer数据和你构建出的twrp结合生出来一个杂交镜像骗过校验。
~~~

## Credits
* [4accccc](https://github.com/4accccc) 设备提供，debug以及手写部分debug代码。
* [twrpdtgen](https://github.com/twrpdtgen/twrpdtgen) 设备树生成器，但是生成出来的设备树编译出来的rec啥都干不了。
* [vivo-4.x-kernel-autopatch](https://github.com/4accccc/vivo-4.x-kernel-autopatch) 修补kernel文件，破除mount限制。
* [Claude Code](https://github.com/anthropics/claude-code) 提供make_hybrid.py，辅助重写Keymaster.cpp等解密相关的文件。
* [platform_manifest_twrp_aosp](https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp) Minimal manifest for building TWRP for devices shipped with Android 10+.
* [android_system_vold](https://github.com/4accccc/android_system_vold) 修改完成的system_vold，如果patches应用失败可以到这里把最新commit更改的文件全部丢到/system/vold里。
* [Android 10 system_vold](https://android.googlesource.com/platform/system/vold/+/refs/tags/android-10.0.0_r47) 对重写解密相关文件，理解原理十分有帮助。
