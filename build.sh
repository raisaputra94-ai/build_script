#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# Install compatibility libraries
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb && \
  sudo dpkg -i libtinfo5_6.3-2_amd64.deb && \
  rm -f libtinfo5_6.3-2_amd64.deb || true

wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb && \
  sudo dpkg -i libncurses5_6.3-2_amd64.deb && \
  rm -f libncurses5_6.3-2_amd64.deb || true

repo init \
  -u https://github.com/LineageOS/android.git \
  -b lineage-18.1 \
  --depth=1 \
  --git-lfs

# Remove old device-specific sources and manifests.
rm -rf \
  device/oppo vendor/oppo kernel/oppo \
  device/realme vendor/realme kernel/realme \
  .repo/local_manifests

mkdir -p .repo/local_manifests
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />
  <project name="RMX1805/device_oppo_RMX1805" path="device/oppo/RMX1805" remote="gh" revision="lineage-18.1" />
  <project name="RMX1805/vendor_oppo" path="vendor/oppo" remote="gh" revision="lineage-18.1" />
</manifest>
XMLEOF

# Sync sources.
for i in 1 2; do
  /opt/crave/resync.sh
done

# Fetch and apply the requested LineageOS 18.1 platform patches.
PATCH_REPO_DIR="/tmp/bimuafaq-local_manifests"
PATCH_DIR="$PATCH_REPO_DIR/lineageos-18.1/patches"

rm -rf "$PATCH_REPO_DIR"
git clone --depth=1 \
  https://github.com/bimuafaq/local_manifests.git \
  "$PATCH_REPO_DIR"

apply_platform_patch() {
  local project_dir="$1"
  local patch_file="$2"
  local patch_name
  patch_name="$(basename "$patch_file")"

  if [[ ! -d "$project_dir" ]]; then
    echo "ERROR: Source project not found: $project_dir" >&2
    exit 1
  fi

  if [[ ! -f "$patch_file" ]]; then
    echo "ERROR: Patch file not found: $patch_file" >&2
    exit 1
  fi

  if git -C "$project_dir" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
    echo "Skipping $patch_name for $project_dir: already applied"
  elif git -C "$project_dir" apply --check "$patch_file"; then
    git -C "$project_dir" apply "$patch_file"
    echo "Applied $patch_name to $project_dir"
  else
    echo "ERROR: $patch_name does not apply cleanly to $project_dir" >&2
    exit 1
  fi
}

apply_platform_patch "build/make"       "$PATCH_DIR/build.patch"
apply_platform_patch "system/core"      "$PATCH_DIR/core.patch"
apply_platform_patch "external/selinux" "$PATCH_DIR/selinux.patch"
apply_platform_patch "system/sepolicy"  "$PATCH_DIR/sepolicy.patch"

BOARD_CONFIG="device/oppo/RMX1805/BoardConfig.mk"

# A real user build must not disable SELinux neverallow validation. Remove the
# device-tree override instead of modifying AOSP's user-build safety guard.
sed -i \
  '/^[[:space:]]*SELINUX_IGNORE_NEVERALLOWS[[:space:]]*:=[[:space:]]*true[[:space:]]*$/d' \
  "$BOARD_CONFIG"

if grep -Eq \
  '^[[:space:]]*SELINUX_IGNORE_NEVERALLOWS[[:space:]]*:=[[:space:]]*true' \
  "$BOARD_CONFIG"; then
  echo "ERROR: Failed to enable SELinux neverallow validation" >&2
  exit 1
fi

echo "SELinux neverallow validation enabled for the user build."

# Match the known-working 2021 userdebug ROM. That build predates the
# September 2021 AVB commit and its boot.img has no AVB footer at all.
# Remove the complete BOARD_AVB_* configuration, including BOARD_AVB_ENABLE.
sed -i '/^[[:space:]]*BOARD_AVB_/d' "$BOARD_CONFIG"

# Stop instead of silently building if any board AVB setting remains.
if grep -Eq '^[[:space:]]*BOARD_AVB_' "$BOARD_CONFIG"; then
  echo "ERROR: Failed to remove BOARD_AVB settings" >&2
  grep -nE '^[[:space:]]*BOARD_AVB_' "$BOARD_CONFIG" >&2
  exit 1
fi

echo "AVB board settings removed successfully."

# Ensure Android init does not deliberately turn an early fatal signal into a
# fastboot reboot. User builds default to 0; this also guards against patches
# or stale configuration re-enabling the behavior.
INIT_BP="system/core/init/Android.bp"
INIT_MK="system/core/init/Android.mk"

sed -i \
  's/-DREBOOT_BOOTLOADER_ON_PANIC=1/-DREBOOT_BOOTLOADER_ON_PANIC=0/g' \
  "$INIT_BP" "$INIT_MK"

# Stop rather than silently producing another bootloader-rebooting build.
if grep -Hn -- '-DREBOOT_BOOTLOADER_ON_PANIC=1' "$INIT_BP" "$INIT_MK"; then
  echo "ERROR: Failed to disable init panic-to-bootloader behavior" >&2
  exit 1
fi

echo "Init panic-to-bootloader behavior disabled successfully."
grep -Hn -- 'REBOOT_BOOTLOADER_ON_PANIC' "$INIT_BP" "$INIT_MK" || true

# Completely clean this device's output and init's Soong intermediates so the
# patched init binary cannot be reused from a previous build.
rm -rf \
  out/target/product/RMX1805 \
  out/soong/.intermediates/system/core/init

source build/envsetup.sh

# Build as user. Permissive-domain checks are relaxed by the imported patch,
# while SELinux neverallow validation remains enabled.
lunch lineage_RMX1805-user
mka bacon
