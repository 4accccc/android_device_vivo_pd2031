#!/system/bin/sh
# 删了你手机就只能进rec了
dd if=/dev/zero of=/dev/block/by-name/misc bs=2048 count=1 2>/dev/null
sync
