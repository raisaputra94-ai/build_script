#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=rai
export TZ=Asia/Singapore

# Install libs
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb && \
    sudo dpkg -i libtinfo5_6.3-2_amd64.deb && rm -f libtinfo5_6.3-2_amd64.deb || true
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb && \
    sudo dpkg -i libncurses5_6.3-2_amd64.deb && rm -f libncurses5_6.3-2_amd64.deb || true

repo init -u https://github.com/LineageOS/android.git -b lineage-18.1 --depth=1 --git-lfs

# Clean up
rm -rf device/oppo vendor/oppo kernel/oppo device/realme vendor/realme kernel/realme
rm -rf .repo/local_manifests

# Set up local manifest
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />
  <project name="Adi-sdm/device_oppo_RMX1805"
           path="device/oppo/RMX1805"
           remote="gh"
           revision="AOSP" />
  <project name="RMX1805/vendor_oppo"
           path="vendor/oppo"
           remote="gh"
           revision="lineage-18.1" />
</manifest>
XMLEOF

# Sync
for i in 1 2; do /opt/crave/resync.sh; done

rm device/oppo/RMX1805/vendorsetup.sh
mv device/oppo/RMX1805/aosp_RMX1805.mk device/oppo/RMX1805/lineage_RMX1805.mk
sed -i 's/aosp_RMX1805/lineage_RMX1805/g' device/oppo/RMX1805/AndroidProducts.mk
sed -i 's/aosp_RMX1805/lineage_RMX1805/g' device/oppo/RMX1805/lineage_RMX1805.mk
sed -i 's|vendor/aosp/config/common_full_phone.mk|vendor/lineage/config/common_full_phone.mk|g' device/oppo/RMX1805/lineage_RMX1805.mk
sed -i '/ARCANE_/d' device/oppo/RMX1805/lineage_RMX1805.mk
sed -i '/ArcaneOS/d' device/oppo/RMX1805/lineage_RMX1805.mk

# Build
source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka bacon
