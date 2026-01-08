#!/system/bin/sh
# Write BCB (bootloader control block) to misc partition for recovery boot
# Then reboot

MISC_PARTITION="/dev/block/by-name/misc"

# Write "boot-recovery" command to BCB
echo -n "boot-recovery" > /tmp/bcb_command
dd if=/dev/zero bs=2048 count=1 2>/dev/null | dd of=$MISC_PARTITION bs=2048 count=1 2>/dev/null
dd if=/tmp/bcb_command of=$MISC_PARTITION bs=1 count=13 2>/dev/null
sync

# Reboot
/system/bin/reboot
