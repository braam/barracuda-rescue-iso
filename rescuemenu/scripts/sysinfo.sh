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

  # Init arrays as string
  pairs=""

  # Get model
  model=$(chroot /mnt/CGFW/ /bin/sh -c "grep '^APPLIANCE' /opt/phion/config/configroot/box.conf | cut -d= -f2 | xargs")
  pairs=$(printf "%s\nmodel=%s" "$pairs" "$model")

  # Get serial
  serial=$(chroot /mnt/CGFW/ /bin/sh -c "/opt/phion/bin/hwtool -e 2>/dev/null | grep -o 'SN = .*' | cut -f2- -d=" | xargs)
  pairs=$(printf "%s\nserial=%s" "$pairs" "$serial")

  # Get Version information
  tmpfile="/tmp/version_output.txt" #Store output in temp file
  chroot /mnt/CGFW/ /bin/sh -c "/opt/phion/bin/version.py" 2>/dev/null | grep -E '^(version|nightbuild|type|mip):' > "$tmpfile"

  while IFS=: read key value; do
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    pairs=$(printf "%s\n%s=%s" "$pairs" "$key" "$value")
  done < "$tmpfile"

  rm -f "$tmpfile" # Remove temp file

  # Print output
  echo "$pairs" | sed '/^$/d' | while IFS== read key val; do
    printf "%-12s\t%s\n" "$key:" "$val"
  done

else
  printf "[!!] Failed to mount Barracuda root partition.\n"
fi

# CLEANUP
sleep 1
umount $MOUNTPOINT/dev $MOUNTPOINT/proc $MOUNTPOINT/sys
umount $MOUNTPOINT

exit 0
