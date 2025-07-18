#!/bin/sh
echo 3 > /proc/sys/kernel/printk # silence kernel messages

MOUNTPOINT="/mnt/CGFW"
RESTOREPARNAME="box.par"
RESTOREPATH_CHROOT="/opt/phion/update"
RESTOREPATH_USB="/mnt/USB"

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

  # Perform restore
  # Copy box.par file from USB drive to CHROOT (CGFW)
  if [ -f "$RESTOREPATH_USB/$RESTOREPARNAME" ]; then
    cp $RESTOREPATH_USB/$RESTOREPARNAME $RESTOREPATH_CHROOT/$RESTOREPARNAME
    # Ring the bell and return success message
    chroot $MOUNTPOINT /bin/sh -c "/opt/phion/bin/hwtool -a 1" >/dev/null 2>&1
    printf ">> Succesfully restored box.par file on CGFW, reboot CGFW now.\n"
  else
    # Try mounting USB drive again..
    mount -L "BAR_RESCUE" /mnt/USB
    if [ $? -ne 0 ]; then
      echo "[!!] Failed to mount USB drive.\n"
      exit 1
    else
      if [ -f "$RESTOREPATH_USB/$RESTOREPARNAME" ]; then
        cp $RESTOREPATH_USB/$RESTOREPARNAME $RESTOREPATH_CHROOT/$RESTOREPARNAME
        # Ring the bell and return success message
        chroot $MOUNTPOINT /bin/sh -c "/opt/phion/bin/hwtool -a 1" >/dev/null 2>&1
        printf ">> Succesfully restored box.par file on CGFW, reboot CGFW now.\n"
      else
       printf "[!!] No box.par file found on root path @ USB drive!\n"
      fi
    fi
  fi
else
  printf "[!!] Failed to mount Barracuda root partition.\n"
fi

# CLEANUP
sleep 1
umount $MOUNTPOINT/dev $MOUNTPOINT/proc $MOUNTPOINT/sys
umount $MOUNTPOINT

exit 0
