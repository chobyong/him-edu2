#!/bin/bash
# make-installer-usb.sh
# Creates an unattended HimEdu Debian installer from an existing Debian ISO or USB.
#
# Usage:
#   sudo bash make-installer-usb.sh <source> <target>
#
# <target> can be:
#   /dev/sdX           — write bootable USB directly
#   /path/to/out.iso   — save as ISO file (flash with Rufus, Etcher, dd, etc.)
#
# Examples:
#   sudo bash make-installer-usb.sh debian.iso /dev/sdc
#   sudo bash make-installer-usb.sh debian.iso /home/him/him-edu.iso
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
SOURCE_ISO="$WORK_DIR/source.iso"
OUTPUT_ISO="$WORK_DIR/him-edu-installer.iso"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
info() { echo -e "\n${GREEN}[INFO]${RESET} $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
err()  { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

# ── Validate ──────────────────────────────────────────────────────────────────
[[ -z "$SOURCE" || -z "$TARGET" ]] && {
  echo "Usage: sudo bash make-installer-usb.sh <source> <target>"
  echo ""
  echo "  source  — Debian ISO file or USB device (e.g. /dev/sdb)"
  echo "  target  — USB device (/dev/sdX) OR output ISO path (/path/to/out.iso)"
  echo ""
  echo "Examples:"
  echo "  sudo bash make-installer-usb.sh debian.iso /dev/sdc"
  echo "  sudo bash make-installer-usb.sh debian.iso /home/him/him-edu.iso"
  exit 1
}

[[ $EUID -ne 0 ]] && err "Run as root: sudo bash $0 $*"

# Determine output mode: USB device or ISO file
TARGET_IS_USB=false
TARGET_IS_ISO=false
if [[ -b "$TARGET" ]]; then
  TARGET_IS_USB=true
  [[ "$SOURCE" = "$TARGET" ]] && err "Source and target cannot be the same device."
elif [[ "$TARGET" == *.iso ]]; then
  TARGET_IS_ISO=true
  TARGET_DIR="$(dirname "$TARGET")"
  [[ -d "$TARGET_DIR" ]] || err "Output directory '$TARGET_DIR' does not exist."
else
  err "Target '$TARGET' is not a block device and does not end in .iso"
fi

for cmd in xorriso dd find awk; do
  command -v "$cmd" &>/dev/null || err "Missing tool: $cmd  →  sudo apt install xorriso"
done

# ── Confirm ───────────────────────────────────────────────────────────────────
if $TARGET_IS_USB; then
  TARGET_SIZE=$(lsblk -dno SIZE "$TARGET" 2>/dev/null || echo "unknown")
  TARGET_LABEL="$TARGET ($TARGET_SIZE) [USB]"
else
  TARGET_LABEL="$TARGET [ISO file]"
fi
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║      HimEdu Unattended Debian Installer Builder      ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Source  : %-41s║\n" "$SOURCE"
printf "║  Output  : %-41s║\n" "$TARGET_LABEL"
printf "║  Hostname: %-41s║\n" "$HOSTNAME"
printf "║  User    : %-20s Password: %-10s║\n" "$USERNAME" "$USER_PASS"
printf "║  Timezone: %-41s║\n" "$TIMEZONE"
echo "╠══════════════════════════════════════════════════════╣"
if $TARGET_IS_USB; then
  echo "║  ⚠  ALL DATA ON $TARGET WILL BE ERASED               ║"
else
  echo "║  Output ISO will be saved to the path above.         ║"
fi
echo "╚══════════════════════════════════════════════════════╝"
echo ""
read -rp "Continue? [y/N] " confirm
[[ "${confirm,,}" != "y" ]] && { echo "Aborted."; exit 0; }

# ── Setup work dir ────────────────────────────────────────────────────────────
rm -rf "$WORK_DIR"
mkdir -p "$ISO_WORK"

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
# Written directly into ISO root so the installer can read it via file=/cdrom/preseed.cfg
cat > "$ISO_WORK/preseed.cfg" << PRESEED
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
tasksel tasksel/first multiselect standard, ssh-server, kde-desktop
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

# ── Step 4: Place preseed in ISO root ─────────────────────────────────────────
info "Step 4/7 — Placing preseed.cfg in ISO root..."
# preseed.cfg is already written to $ISO_WORK/preseed.cfg in Step 3.
# The installer loads it via file=/cdrom/preseed.cfg (Debian mounts install media at /cdrom).
[[ -f "$ISO_WORK/preseed.cfg" ]] || err "preseed.cfg missing from ISO work dir."
ok "preseed.cfg placed at ISO root."

# ── Step 5: Patch boot configs ────────────────────────────────────────────────
info "Step 5/7 — Patching boot configuration..."
PRESEED_PARAMS="auto=true priority=critical file=/cdrom/preseed.cfg"

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

# ── Step 7: Deliver output ────────────────────────────────────────────────────
if $TARGET_IS_USB; then
  info "Step 7/7 — Writing to USB $TARGET..."
  for part in "${TARGET}"?*; do
    umount "$part" 2>/dev/null || true
  done
  dd if="$OUTPUT_ISO" of="$TARGET" bs=4M status=progress conv=fsync 2>&1
  sync
  FINAL_MSG="USB written to $TARGET — ready to boot."
else
  info "Step 7/7 — Saving ISO to $TARGET..."
  cp "$OUTPUT_ISO" "$TARGET"
  FINAL_MSG="ISO saved: $TARGET  ($(du -sh "$TARGET" | cut -f1))"
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              HimEdu Installer Ready!                 ║"
echo "╠══════════════════════════════════════════════════════╣"
if $TARGET_IS_ISO; then
  printf "║  ISO: %-46s║\n" "$TARGET"
  echo "║  Flash with: Rufus, Etcher, or:                      ║"
  printf "║    dd if=%s of=/dev/sdX bs=4M status=progress ║\n" "$(basename "$TARGET")"
else
  echo "║  1. Plug this USB into the target computer           ║"
  echo "║  2. Boot from USB (F12 / F2 / Del for boot menu)    ║"
fi
echo "║  3. Installer runs fully automatically               ║"
echo "║  4. Server reboots → setup.sh runs on first boot     ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Login after setup: %-32s║\n" "${USERNAME} / ${USER_PASS}"
echo "║  Tailscale: run 'sudo tailscale up --ssh' after      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
