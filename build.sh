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
rm -rf device/realme/RMX1805
rm -rf vendor/realme/RMX1805
rm -rf kernel/realme/RMX1805
rm -rf device/oppo/RMX1805
rm -rf vendor/oppo/RMX1805
rm -rf kernel/oppo/RMX1805
rm -rf .repo/local_manifests

# Set up local manifest with ALL repos
mkdir -p .repo/local_manifests
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />
  <project name="noophyy/device_realme_RMX1805"
           path="device/realme/RMX1805"
           remote="gh"
           revision="oss" />
  <project name="noophyy/vendor_realme_rmx1805"
           path="vendor/realme/RMX1805"
           remote="gh"
           revision="oss" />
  <project name="noophyy/kernel_realme_msm8953"
           path="kernel/realme/RMX1805"
           remote="gh"
           revision="Light" />
</manifest>
XMLEOF

# Sync everything via resync (no conflicts)
/opt/crave/resync.sh

# Now envsetup won't trigger broken vendorsetup.sh
source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka bacon
