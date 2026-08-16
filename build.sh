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

# Match the known-working boot image: retain BOARD_AVB_ENABLE=true so
# boot.img gets an AVB hash footer, but do not set disabled-verification
# flags on generated vbmeta metadata.
sed -i \
  -e '/BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS.*--set_hashtree_disabled_flag/d' \
  -e '/BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS.*--flag[[:space:]]*2/d' \
  "$BOARD_CONFIG"

# Stop instead of silently building if the unwanted settings remain.
if grep -Eq \
  'BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS.*(--set_hashtree_disabled_flag|--flag[[:space:]]*2)' \
  "$BOARD_CONFIG"; then
  echo "ERROR: Failed to remove disabled-verification AVB arguments" >&2
  exit 1
fi

echo "Final AVB configuration:"
grep -nE 'BOARD_AVB|VBMETA' "$BOARD_CONFIG" || true

# Completely clean this device's previous output.
rm -rf out/target/product/RMX1805

source build/envsetup.sh

# The known-working reference ROM is a user build, not userdebug.
lunch lineage_RMX1805-user
mka bacon
