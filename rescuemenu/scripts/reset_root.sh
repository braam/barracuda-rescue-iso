#!/bin/sh
echo 3 > /proc/sys/kernel/printk # silence kernel messages

MOUNTPOINT="/mnt/CGFW"

printf "[*] Searching for Barracuda root partitions...\n"
sleep 1
printf "[*] Mounting Barracuda root partition.\n"

if [ ! -d "$MOUNTPOINT" ]; then
  mkdir -p "$MOUNTPOINT"
fi

mount /dev/vg_root/lv_root $MOUNTPOINT

# Check if mount was succesful
if [ $? -eq 0 ]; then
  # Create necessary bindings
  mount --bind /dev $MOUNTPOINT/dev
  mount --bind /proc $MOUNTPOINT/proc
  mount --bind /sys $MOUNTPOINT/sys

  # Return success message
  printf ">> Root partition succesfully mounted.\n"
  sleep 1

  # Set root password to default password
  chroot $MOUNTPOINT echo 'root:ngf1r3wall'| chpasswd >/dev/null 2>&1

  # Check if password reset was succesful
  if [ $? -eq 0 ]; then
    # Ring the bell and return success message
    chroot $MOUNTPOINT /bin/sh -c "/opt/phion/bin/hwtool -a 1" >/dev/null 2>&1
    printf ">> Root password has been successfully restored to default password: ngf1r3wall\n"
  else
    printf "[!!] Failed to reset root password.\n"
  fi

else
  printf "[!!] Failed to mount Barracuda root partition.\n"
fi

# CLEANUP
sleep 1
umount $MOUNTPOINT/dev $MOUNTPOINT/proc $MOUNTPOINT/sys
umount $MOUNTPOINT

exit 0
