#!/bin/bash
# make-installer-usb.sh
# Creates an unattended HimEdu Debian installer USB from an existing Debian ISO or USB.
#
# Usage:
#   sudo bash make-installer-usb.sh <source> <target-usb>
#
# Examples:
#   sudo bash make-installer-usb.sh /dev/sdb /dev/sdc   # source=USB, target=USB
#   sudo bash make-installer-usb.sh debian.iso /dev/sdc  # source=ISO file, target=USB
#
# The installer will:
#   - Install Debian fully unattended (no keyboard input required)
#   - Create user 'him' with sudo rights
#   - Clone the him-edu2 repo and run setup.sh automatically on first boot

set -euo pipefail

SOURCE="${1:-}"
TARGET="${2:-}"

# ── Configuration (matches setup.sh defaults) ─────────────────────────────────
HOSTNAME="him-edu"
USERNAME="him"
USER_PASS="ABCD_1234"
TIMEZONE="America/Los_Angeles"
LOCALE="en_US"
REPO_URL="https://github.com/chobyong/him-edu2.git"
# ─────────────────────────────────────────────────────────────────────────────

WORK_DIR="/tmp/him-edu-installer"
ISO_WORK="$WORK_DIR/iso"
INITRD_WORK="$WORK_DIR/initrd"
SOURCE_ISO="$WORK_DIR/source.iso"
OUTPUT_ISO="$WORK_DIR/him-edu-installer.iso"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
info() { echo -e "\n${GREEN}[INFO]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

# ── Validate ──────────────────────────────────────────────────────────────────
[[ -z "$SOURCE" || -z "$TARGET" ]] && {
  echo "Usage: sudo bash make-installer-usb.sh <source-device-or-iso> <target-usb>"
  echo ""
  echo "  source  — Debian installer USB device (e.g. /dev/sdb) or ISO file"
  echo "  target  — USB device to write the new installer to (e.g. /dev/sdc)"
  echo ""
  echo "Example (USB to USB):"
  echo "  sudo bash make-installer-usb.sh /dev/sdb /dev/sdc"
  exit 1
}

[[ $EUID -ne 0 ]] && err "Run as root: sudo bash $0 $*"

[[ ! -b "$TARGET" ]] && err "Target '$TARGET' is not a block device."
[[ "$SOURCE" = "$TARGET" ]] && err "Source and target cannot be the same device."

for cmd in xorriso cpio gzip dd find awk; do
  command -v "$cmd" &>/dev/null || err "Missing tool: $cmd  →  sudo apt install xorriso cpio gzip"
done

# ── Confirm ───────────────────────────────────────────────────────────────────
TARGET_SIZE=$(lsblk -dno SIZE "$TARGET" 2>/dev/null || echo "unknown")
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║      HimEdu Unattended Debian Installer Builder      ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Source  : %-41s║\n" "$SOURCE"
printf "║  Target  : %-25s (%s)%-6s║\n" "$TARGET" "$TARGET_SIZE" ""
printf "║  Hostname: %-41s║\n" "$HOSTNAME"
printf "║  User    : %-20s Password: %-10s║\n" "$USERNAME" "$USER_PASS"
printf "║  Timezone: %-41s║\n" "$TIMEZONE"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  ⚠  ALL DATA ON $TARGET WILL BE ERASED               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
read -rp "Continue? [y/N] " confirm
[[ "${confirm,,}" != "y" ]] && { echo "Aborted."; exit 0; }

# ── Setup work dir ────────────────────────────────────────────────────────────
rm -rf "$WORK_DIR"
mkdir -p "$ISO_WORK" "$INITRD_WORK"

# ── Step 1: Get source ISO ────────────────────────────────────────────────────
info "Step 1/7 — Preparing source ISO..."
if [[ -b "$SOURCE" ]]; then
  echo "  Copying from device $SOURCE (may take a few minutes)..."
  dd if="$SOURCE" of="$SOURCE_ISO" bs=4M status=progress conv=sync 2>&1
  ok "ISO copied from device."
elif [[ -f "$SOURCE" ]]; then
  SOURCE_ISO="$SOURCE"
  ok "Using ISO file: $SOURCE_ISO"
else
  err "Source '$SOURCE' is not a block device or file."
fi

# ── Step 2: Extract ISO ───────────────────────────────────────────────────────
info "Step 2/7 — Extracting ISO..."
xorriso -osirrox on -indev "$SOURCE_ISO" -extract / "$ISO_WORK" -- 2>/dev/null | tail -3
chmod -R u+w "$ISO_WORK"
ok "ISO extracted to $ISO_WORK"

# ── Step 3: Create preseed.cfg ────────────────────────────────────────────────
info "Step 3/7 — Writing preseed.cfg..."
cat > "$WORK_DIR/preseed.cfg" << PRESEED
### HimEdu Unattended Debian Installer

# Locale and keyboard
d-i debian-installer/locale string ${LOCALE}.UTF-8
d-i keyboard-configuration/xkb-keymap select us
d-i keyboard-configuration/toggle select No toggling

# Network — DHCP on wired, set hostname
d-i netcfg/choose_interface select auto
# Hostname — installer will prompt for this during network setup
# d-i netcfg/get_hostname string him-edu
d-i netcfg/get_domain string local
d-i netcfg/wireless_wep string

# Mirror
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

# Clock and timezone
d-i clock-setup/utc boolean true
d-i time/zone string ${TIMEZONE}
d-i clock-setup/ntp boolean true

# Partitioning — wipe entire disk, single ext4 partition + swap
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-partitioning/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman/mount_style select uuid

# User accounts — no root login, create ${USERNAME} with sudo
d-i passwd/root-login boolean false
d-i passwd/user-fullname string ${USERNAME}
d-i passwd/username string ${USERNAME}
d-i passwd/user-password password ${USER_PASS}
d-i passwd/user-password-again password ${USER_PASS}
d-i passwd/user-default-groups string sudo audio video cdrom

# Packages
tasksel tasksel/first multiselect standard, ssh-server
d-i pkgsel/include string curl git sudo openssh-server
d-i pkgsel/upgrade select full-upgrade
popularity-contest popularity-contest/participate boolean false

# Bootloader — install to MBR automatically
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default

# Post-install: clone repo, create first-boot service
d-i preseed/late_command string \\
  in-target apt-get install -y curl git; \\
  in-target git clone ${REPO_URL} /opt/him-edu2; \\
  in-target chown -R ${USERNAME}:${USERNAME} /opt/him-edu2; \\
  printf '[Unit]\nDescription=HimEdu first-boot setup\nAfter=network-online.target\nWants=network-online.target\nConditionPathExists=/opt/him-edu2/setup.sh\n\n[Service]\nType=oneshot\nExecStart=/bin/bash /opt/him-edu2/setup.sh\nStandardOutput=journal+console\nStandardError=journal+console\nRemainAfterExit=yes\n\n[Install]\nWantedBy=multi-user.target\n' > /target/etc/systemd/system/him-edu-setup.service; \\
  in-target systemctl enable him-edu-setup.service

# Done
d-i finish-install/reboot_in_progress note
PRESEED
ok "preseed.cfg written."

# ── Step 4: Inject preseed into initrd ────────────────────────────────────────
info "Step 4/7 — Injecting preseed into initrd..."
INITRD_PATH=""
for candidate in \
  "$ISO_WORK/install.amd/initrd.gz" \
  "$ISO_WORK/install/initrd.gz" \
  "$ISO_WORK/install.x86_64/initrd.gz"; do
  [[ -f "$candidate" ]] && { INITRD_PATH="$candidate"; break; }
done
[[ -z "$INITRD_PATH" ]] && err "Cannot find initrd in ISO. Searched: install.amd/, install/, install.x86_64/"
echo "  initrd: $INITRD_PATH"

# Debian initrd may have an early uncompressed cpio section (CPU microcode)
# prepended before the gzip'd rootfs. Find the gzip start offset.
GZIP_OFFSET=$(LANG=C grep -boa $'\x1f\x8b' "$INITRD_PATH" | head -1 | cut -d: -f1 || echo "0")
GZIP_OFFSET="${GZIP_OFFSET:-0}"
echo "  gzip offset: ${GZIP_OFFSET} bytes"

# Split: save any early section, extract gzip portion
if [[ "$GZIP_OFFSET" -gt 0 ]]; then
  dd if="$INITRD_PATH" bs=1 count="$GZIP_OFFSET" of="$WORK_DIR/initrd_early.bin" 2>/dev/null
  dd if="$INITRD_PATH" bs=1 skip="$GZIP_OFFSET" of="$WORK_DIR/initrd_main.gz" 2>/dev/null
else
  cp "$INITRD_PATH" "$WORK_DIR/initrd_main.gz"
fi

# Extract, add preseed, repack
mkdir -p "$INITRD_WORK"
cd "$INITRD_WORK"
gzip -dc "$WORK_DIR/initrd_main.gz" | cpio -id --quiet 2>/dev/null || true
cp "$WORK_DIR/preseed.cfg" "$INITRD_WORK/preseed.cfg"
find . | cpio -H newc -o --quiet 2>/dev/null | gzip -9 > "$WORK_DIR/initrd_new.gz"
cd /

# Recombine early section + new gzip
if [[ "$GZIP_OFFSET" -gt 0 ]]; then
  cat "$WORK_DIR/initrd_early.bin" "$WORK_DIR/initrd_new.gz" > "$INITRD_PATH"
else
  cp "$WORK_DIR/initrd_new.gz" "$INITRD_PATH"
fi

# Verify
if zcat "$INITRD_PATH" 2>/dev/null | cpio -t 2>/dev/null | grep -q "preseed.cfg"; then
  ok "preseed.cfg verified inside initrd."
else
  err "preseed.cfg NOT found in rebuilt initrd — injection failed."
fi

# ── Step 5: Patch boot configs ────────────────────────────────────────────────
info "Step 5/7 — Patching boot configuration..."
PRESEED_PARAMS="auto=true priority=critical preseed/file=/preseed.cfg"

# Patch GRUB (EFI)
for cfg in \
  "$ISO_WORK/boot/grub/grub.cfg" \
  "$ISO_WORK/EFI/boot/grub.cfg"; do
  [[ -f "$cfg" ]] || continue
  # Insert preseed params before the closing --- of each linux/linuxefi line
  sed -i "s|---$|--- ${PRESEED_PARAMS}|g" "$cfg"
  sed -i "s|--- quiet|--- quiet ${PRESEED_PARAMS}|g" "$cfg"
  # Reduce timeout for faster boot
  sed -i 's/^set timeout=.*/set timeout=5/' "$cfg"
  ok "Patched GRUB: $cfg"
done

# Patch isolinux (BIOS)
for cfg in \
  "$ISO_WORK/isolinux/txt.cfg" \
  "$ISO_WORK/isolinux/gtk.cfg"; do
  [[ -f "$cfg" ]] || continue
  sed -i "s|---$|--- ${PRESEED_PARAMS}|g" "$cfg"
  sed -i "s|--- quiet|--- quiet ${PRESEED_PARAMS}|g" "$cfg"
  ok "Patched isolinux: $cfg"
done
# Set isolinux timeout (units: 1/10 seconds, 50 = 5s)
[[ -f "$ISO_WORK/isolinux/isolinux.cfg" ]] && \
  sed -i 's/^timeout .*/timeout 50/' "$ISO_WORK/isolinux/isolinux.cfg"

# ── Step 6: Repack ISO ────────────────────────────────────────────────────────
info "Step 6/7 — Repacking ISO (hybrid BIOS+EFI)..."
# Save MBR from source ISO (needed for isohybrid USB boot)
dd if="$SOURCE_ISO" bs=1 count=432 of="$WORK_DIR/mbr.bin" 2>/dev/null

xorriso -as mkisofs \
  -r -V "HimEdu-Installer" \
  -o "$OUTPUT_ISO" \
  -J -joliet-long \
  -isohybrid-mbr "$WORK_DIR/mbr.bin" \
  -c isolinux/boot.cat \
  -b isolinux/isolinux.bin \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -isohybrid-gpt-basdat \
  "$ISO_WORK" 2>&1 | grep -v "^$" | tail -5

ok "ISO repacked: $OUTPUT_ISO ($(du -sh "$OUTPUT_ISO" | cut -f1))"

# ── Step 7: Write to USB ──────────────────────────────────────────────────────
info "Step 7/7 — Writing to $TARGET..."
# Unmount any partitions on target
for part in "${TARGET}"?*; do
  umount "$part" 2>/dev/null || true
done
dd if="$OUTPUT_ISO" of="$TARGET" bs=4M status=progress conv=fsync 2>&1
sync

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              Installer USB Ready!                    ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  1. Plug this USB into the target computer           ║"
echo "║  2. Boot from USB (F12 / F2 / Del for boot menu)    ║"
echo "║  3. Installer runs fully automatically               ║"
echo "║  4. Server reboots → setup.sh runs on first boot     ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Login after setup: %-32s║\n" "${USERNAME} / ${USER_PASS}"
printf "║  Tailscale: run 'sudo tailscale up --ssh' after   ║\n"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
