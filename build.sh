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

# Clean up
rm -rf device/oppo/RMX1805 vendor/oppo/RMX1805
rm -rf .repo/local_manifests

# Set up local manifest
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />
  <project name="RMX1805/device_oppo_RMX1805"
           path="device/oppo/RMX1805"
           remote="gh"
           revision="lineage-18.1" />
  <project name="RMX1805/vendor_oppo"
           path="vendor/oppo"
           remote="gh"
           revision="lineage-18.1" />
</manifest>
XMLEOF

# Sync
/opt/crave/resync.sh

# FIX 1: Remove fstab encryption
sed -i 's/,encryptable=footer//g' device/oppo/RMX1805/rootdir/etc/fstab.qcom

# FIX 2: Remove fingerprint spoof
sed -i '/ro.build.description/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/ro.build.fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/ro.vendor.build.fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp
sed -i '/\/\/ fingerprint/d' device/oppo/RMX1805/init/init_msm8953.cpp

# FIX 3: Fix AVB flags
sed -i 's/--set_hashtree_disabled_flag/--flags 3/g' device/oppo/RMX1805/BoardConfig.mk
sed -i 's/--flag 2//g' device/oppo/RMX1805/BoardConfig.mk

# FIX 4: Spoof verified boot state
sed -i '/loop.max_part=7/a BOARD_KERNEL_CMDLINE += androidboot.verifiedbootstate=green\nBOARD_KERNEL_CMDLINE += androidboot.vbmeta.device_state=locked\nBOARD_KERNEL_CMDLINE += androidboot.veritymode=enforcing' device/oppo/RMX1805/BoardConfig.mk

# FIX 5: Remove HW disk encryption
sed -i '/TARGET_HW_DISK_ENCRYPTION/d' device/oppo/RMX1805/BoardConfig.mk

# Build
source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka bacon
