#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
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

mkdir -p .repo/local_manifests
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />
  <project name="RMX1805/device_oppo_RMX1805" path="device/oppo/RMX1805" remote="gh" revision="lineage-18.1" />
  <project name="RMX1805/vendor_oppo" path="vendor/oppo" remote="gh" revision="lineage-18.1" />
</manifest>
XMLEOF

# Sync
for i in 1 2; do /opt/crave/resync.sh; done

PATCH_URL="https://raw.githubusercontent.com/bimuafaq/local_manifests/main/lineageos-18.1/patches"

apply_patch() {
    local dir=$1
    local patch=$2
    echo "Applying $patch to $dir..."
    curl -sL "$PATCH_URL/$patch" -o "$patch"
    pushd "$dir" > /dev/null
    git am --3way < "../../$patch" || (git am --abort && echo "Failed to apply $patch")
    popd > /dev/null
    rm "$patch"
}

apply_patch "build/make" "build.patch"
apply_patch "system/core" "core.patch"
apply_patch "external/selinux" "selinux.patch"
apply_patch "system/sepolicy" "sepolicy.patch"

# Fix the AVB typo (--flag to --flags) in official trees
sed -i 's/--flag 2/--flags 2/g' device/oppo/RMX1805/BoardConfig.mk

# Clean fstab from AVB checks (Essential for non-Magisk boot)
sed -i 's/,avb//g' device/oppo/RMX1805/rootdir/etc/fstab.qcom || true

source build/envsetup.sh
lunch lineage_RMX1805-user
mka bacon
