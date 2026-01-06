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
## 如何构建？
最好科学上网。   
先安装依赖
~~~
sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg gperf imagemagick lib32ncurses5-dev lib32readline-dev lib32z1-dev liblz4-tool libncurses5 libncurses5-dev libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev git
~~~
[然后跟着这个教程装repo](https://mirrors.tuna.tsinghua.edu.cn/help/git-repo/)，repo装好了过后，在你的用户目录
~~~
mkdir twrp
cd twrp
export ALLOW_MISSING_DEPENDENCIES := true
repo init -u https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp.git -b twrp-12.1
repo sync -j$(nproc)   # $(nproc)是最大线程，你也可以改小点比如4,2啥的
mkdir -p device/vivo
cd device/vivo
git clone https://github.com/4accccc/android_device_vivo_pd2031.git k6853v1_64_6360
cd ../..
python3 device/vivo/k6853v1_64_6360/patches/apply-patches.sh   # 一定要执行！不然build出来的twrp无法解密分区！
~~~~
这里建议先去BoardConfig.mk修改PLATFORM_SECURITY_PATCH和VENDOR_SECURITY_PATCH，要修改成你手机实际的版本，不然解密不了data。(5.12.1偷渡橘子2的不用改)
~~~~
source build/envsetup.sh
lunch omni_k6853v1_64_6360-eng
mka recoveryimage
python3 device/vivo/k6853v1_64_6360/make_hybrid.py   # 一定要运行！vivo会验证avb footer数据，校验不过tee会返回一个错误的patchlevel(20300101)，无法解密data。
~~~