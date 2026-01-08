#!/system/bin/sh
# Clear BCB (bootloader control block) after entering recovery
dd if=/dev/zero of=/dev/block/by-name/misc bs=2048 count=1 2>/dev/null
sync
