#!/bin/sh
echo 3 > /proc/sys/kernel/printk # silence kernel messages

MOUNTPOINT="/mnt/CGFW"

printf "[*] Searching for Barracuda root partitions...\n"
sleep 1
printf "[*] Mounting Barracuda root partition.\n"

if [ ! -d "$MOUNTPOINT" ]; then
  mkdir -p "$MOUNTPOINT"
fi

# Check if LVM is used or not (V10 is using LVM).
if blkid /dev/vg_root/lv_root > /dev/null 2>&1; then
	mount /dev/vg_root/lv_root $MOUNTPOINT # V10
else
	mount /dev/sda2 $MOUNTPOINT
fi

# Check if mount was successful
if [ $? -eq 0 ]; then
  # Create necessary bindings
  mount --bind /dev $MOUNTPOINT/dev
  mount --bind /proc $MOUNTPOINT/proc
  mount --bind /sys $MOUNTPOINT/sys

  # Return success message
  printf ">> Root partition succesfully mounted.\n"
  sleep 1

  # Set root password to default password
  echo '@reboot   root   /usr/bin/echo "root:ngf1r3wall" | /usr/bin/sudo /usr/sbin/chpasswd && /opt/phion/bin/hwtool -a 2 && /usr/bin/sed -i '\''$d'\'' /etc/cron.d/phioncron' >> $MOUNTPOINT/etc/cron.d/phioncron

  # Check if password reset was succesful
  if [ $? -eq 0 ]; then
    # Ring the bell and return success message
    chroot $MOUNTPOINT /bin/sh -c "/opt/phion/bin/hwtool -a 1" >/dev/null 2>&1
    printf ">> Please reboot the box, after you hear the bell password will be restored to the default one: ngf1r3wall\n"
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
