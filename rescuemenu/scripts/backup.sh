#!/bin/sh
echo 3 > /proc/sys/kernel/printk # silence kernel messages

MOUNTPOINT="/mnt/CGFW"
BACKUPPARNAME="backup_rescue.par"
BACKUPPATH_CHROOT="/tmp"
BACKUPPATH_USB="/mnt/USB"

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

  # Perform backup
  chroot $MOUNTPOINT /bin/sh -c "cd /opt/phion/config/configroot/ && /opt/phion/bin/phionar cdl $BACKUPPATH_CHROOT/$BACKUPPARNAME *"

  # Check if backup was succesful
  if [ $? -eq 0 ]; then
    printf ">> Backup completed succesfully, let's try copying it to the USB drive...\n"
    # Move backup file from CHROOT to USB drive (initramfs)
    if [ -f "$BACKUPPATH_USB/syslinux.cfg" ]; then
      # Move file
      mv $MOUNTPOINT/$BACKUPPATH_CHROOT/$BACKUPPARNAME $BACKUPPATH_USB/$BACKUPPARNAME
      printf ">> Backup file is stored on the USB drive: $BACKUPPARNAME\n"
    else
      # USB not mounted, try to mount again..
      mkdir -p "$BACKUPPATH_USB"
      mount -L "BAR_RESCUE" /mnt/USB || { echo "[!!] Mounting USB drive has failed.\n."; exit 1; }
      # Move file
      mv $MOUNTPOINT/$BACKUPPATH_CHROOT/$BACKUPPARNAME $BACKUPPATH_USB/$BACKUPPARNAME
      printf ">> Backup file is stored on the USB drive: $BACKUPPARNAME\n"
    fi
  else
    printf "[!!] Failed to create backup file.\n"
  fi

else
  printf "[!!] Failed to mount Barracuda root partition.\n"
fi

# CLEANUP
sleep 1
umount $MOUNTPOINT/dev $MOUNTPOINT/proc $MOUNTPOINT/sys
umount $MOUNTPOINT

exit 0
