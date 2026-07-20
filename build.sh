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

# Remove old device/vendor folders AND .repo caches
rm -rf device/oppo/RMX1805
rm -rf device/realme/RMX1805
rm -rf vendor/oppo/RMX1805
rm -rf vendor/realme/RMX1805
rm -rf vendor/bcr
rm -rf .repo/projects/device/oppo/RMX1805.git
rm -rf .repo/projects/device/realme/RMX1805.git
rm -rf .repo/projects/vendor/oppo
rm -rf .repo/projects/vendor/realme
rm -rf .repo/projects/vendor/bcr
rm -rf .repo/project-objects/device/oppo/RMX1805.git
rm -rf .repo/project-objects/device/realme/RMX1805.git
rm -rf .repo/project-objects/vendor/oppo
rm -rf .repo/project-objects/vendor/realme
rm -rf .repo/project-objects/vendor/bcr
rm -rf .repo/project-objects/LinuxGuy312
rm -rf .repo/local_manifests

# Init LineageOS 18.1
mkdir -p .repo/local_manifests
repo init -u https://github.com/LineageOS/android.git \
    -b lineage-18.1 \
    --depth=1 \
    --git-lfs

# LinuxGuy312 device + vendor
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />
  <project name="LinuxGuy312/device_oppo_RMX1805"
           path="device/oppo/RMX1805"
           remote="gh"
           revision="11" />
  <project name="LinuxGuy312/vendor_oppo_RMX1805"
           path="vendor/oppo/RMX1805"
           remote="gh"
           revision="11" />
</manifest>
XMLEOF

# Sync
/opt/crave/resync.sh

# Remove fingerprint spoof from init
sed -i '/ro.build.description/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/ro.build.fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/ro.vendor.build.fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/\/\/ fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp

# Add AudioFX
# echo 'PRODUCT_PACKAGES += AudioFX' >> device/oppo/RMX1805/device.mk

# Build
source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka bacon
