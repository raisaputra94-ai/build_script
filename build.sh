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

# Nuclear cleanup - remove EVERYTHING that could conflict
rm -rf device/oppo/RMX1805
rm -rf vendor/oppo/RMX1805
rm -rf vendor/bcr
rm -rf kernel/oppo/RMX1805
rm -rf .repo/local_manifests

# Set up local manifest with ALL repos
mkdir -p .repo/local_manifests
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
  <project name="selfmusing/vendor_bcr"
           path="vendor/bcr"
           remote="gh"
           revision="main" />
  <project name="LinuxGuy312/android_kernel_realme_RMX1805"
           path="kernel/oppo/RMX1805"
           remote="gh"
           revision="main" />
</manifest>
XMLEOF

# Sync everything via resync (no conflicts)
/opt/crave/resync.sh

# DELETE the broken vendorsetup.sh BEFORE envsetup
rm -f device/oppo/RMX1805/vendorsetup.sh

# Set up KernelSU manually (what vendorsetup.sh was supposed to do)
cd kernel/oppo/RMX1805
curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s v0.9.5
cd /tmp/src/android

# Remove fingerprint spoof
sed -i '/ro.build.description/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/ro.build.fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/ro.vendor.build.fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/\/\/ fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp

# Add AudioFX
echo 'PRODUCT_PACKAGES += AudioFX' >> device/oppo/RMX1805/device.mk

# Now envsetup won't trigger broken vendorsetup.sh
source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka bacon
