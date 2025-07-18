#!/bin/bash
set -e

ALPINE_VERSION_FULL=3.20.0
ALPINE_VERSION_MAJOR=3.20
ARCH=x86_64
WORKDIR=$(pwd)
ISO_LABEL="BAR_RESCUE"
ISO_NAME="barracuda-rescue.iso"
MINIROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION_MAJOR}/releases/${ARCH}/alpine-minirootfs-${ALPINE_VERSION_FULL}-${ARCH}.tar.gz"
KERNEL_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION_MAJOR}/releases/${ARCH}/netboot/vmlinuz-lts"
APK_REPO="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION_MAJOR}/main/${ARCH}/"

# Function to find the correct linux-lts package (exclude -dev and -doc)
get_pkg() {
  local prefix="$1"
  wget -q -O - "$APK_REPO" | \
    grep -o "${prefix}-[^\"']*\.apk" | \
    grep -v -E '(-dev|-doc)\.apk' | \
    head -n1
}

LINUX_LTS_PKG=$(get_pkg "linux-lts")
echo "📦 Found linux-lts package: $LINUX_LTS_PKG"

# Download linux-lts APK if not present
if [ ! -f "$LINUX_LTS_PKG" ]; then
  wget -O "$LINUX_LTS_PKG" "${APK_REPO}${LINUX_LTS_PKG}"
fi

# Clean previous build files
rm -rf rootfs iso initramfs.gz initrd.img iso/${ISO_NAME}
mkdir -p rootfs iso/boot initramfs/scripts

# Download MinirootFS if not present
if [ ! -f alpine-minirootfs.tar.gz ]; then
    wget -O alpine-minirootfs.tar.gz "$MINIROOTFS_URL"
fi

# Extract MinirootFS
tar -xzf alpine-minirootfs.tar.gz -C rootfs

# Ensure DNS works inside rootfs
echo "nameserver 1.1.1.1" > rootfs/etc/resolv.conf

# Install required packages inside rootfs
chroot rootfs /bin/sh -c "apk update && apk add --no-cache bash lvm2 e2fsprogs util-linux coreutils rsync"

# Extract kernel modules from downloaded linux-lts APK and copy into rootfs
mkdir -p modules_tmp
tar --warning=no-unknown-keyword -xzf "$LINUX_LTS_PKG" -C modules_tmp
if [ -d modules_tmp/lib/modules ]; then
  mkdir -p rootfs/lib/
  cp -r modules_tmp/lib/modules rootfs/lib/
else
  echo "❌ Error: No kernel modules found in the APK!"
  exit 1
fi
rm -rf modules_tmp

# Create the init script for the initramfs
cp rescuemenu/init rootfs/init
chmod +x rootfs/init

# Copy the custom rescue scripts for the initramfs
mkdir -p rootfs/rescuemenu
cp -r rescuemenu/scripts rootfs/rescuemenu/scripts
chmod -R +x rootfs/rescuemenu/scripts

# Build the initramfs image
cd rootfs
find . | cpio -o -H newc | gzip -9 > "$WORKDIR/initramfs.gz"
cd "$WORKDIR"

# Download kernel image
wget -O iso/boot/vmlinuz "$KERNEL_URL"

# Create bootloader config
cat > iso/boot/isolinux.cfg <<EOF
DEFAULT linux
LABEL linux
  KERNEL /boot/vmlinuz
  APPEND initrd=/boot/initramfs.gz console=tty0 console=ttyS0,19200n8
EOF

# Copy syslinux bootloader files
cp /usr/lib/ISOLINUX/isolinux.bin iso/boot/
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 iso/boot/

# Copy initramfs to ISO directory
cp initramfs.gz iso/boot/

# Create the ISO image
xorriso -as mkisofs \
  -o ${ISO_NAME} \
  -b boot/isolinux.bin \
  -c boot/boot.cat \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -R -J -V "${ISO_LABEL}" \
  iso

echo "✅ ISO built: ${ISO_NAME}"

