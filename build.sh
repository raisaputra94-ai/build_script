#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=rai
export TZ=Asia/Singapore

# Install libncurses5 (non-fatal if blocked)
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb && \
    sudo dpkg -i libtinfo5_6.3-2_amd64.deb && rm -f libtinfo5_6.3-2_amd64.deb || true
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb && \
    sudo dpkg -i libncurses5_6.3-2_amd64.deb && rm -f libncurses5_6.3-2_amd64.deb || true

# Remove old local manifests
rm -rf .repo/local_manifests
mkdir -p .repo/local_manifests

# Create manifest with renamed remote (avoids "github" conflict)
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="rmx1805" fetch="https://github.com/" />
  <project name="RMX1805/device_oppo_RMX1805" path="device/oppo/RMX1805" remote="rmx1805" revision="lineage-18.1" />
  <project name="RMX1805/vendor_oppo" path="vendor/oppo" remote="rmx1805" revision="lineage-18.1" />
</manifest>
XMLEOF

# Sync
/opt/crave/resync.sh

# Build
source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka bacon
