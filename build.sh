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

BOARD_CONFIG="device/oppo/RMX1805/BoardConfig.mk"

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


# Completely clean this device's previous output.
rm -rf out/target/product/RMX1805

source build/envsetup.sh

# Use userdebug because this device tree's permissive/legacy SELinux policy
# does not currently pass the stricter user-build policy checks.
lunch lineage_RMX1805-userdebug
mka bacon
