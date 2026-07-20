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

# Remove old local manifests
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

# Init LineageOS 18.1
repo init -u https://github.com/LineageOS/android.git \
    -b lineage-18.1 \
    --depth=1 \
    --git-lfs

# noophyy device + vendor trees
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="noophyy" fetch="https://github.com/" />
  <project name="noophyy/device_realme_RMX1805"
           path="device/realme/RMX1805"
           remote="noophyy"
           revision="oss" />
  <project name="noophyy/vendor_realme_rmx1805"
           path="vendor/realme/RMX1805"
           remote="noophyy"
           revision="oss" />
</manifest>
XMLEOF

# Sync
/opt/crave/resync.sh

rm -rf device/realme/RMX1805/lights
sed -i '/android.hardware.lights-service.RMX1805/d' device/realme/RMX1805/device.mk

# Build
source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka bacon
