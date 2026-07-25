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
  <project name="RMX1805/device_oppo_RMX1805" path="device/oppo/RMX1805" remote="github" revision="lineage-18.1" />
  <project name="RMX1805/vendor_oppo_RMX1805" path="vendor/oppo" remote="github" revision="lineage-18.1" />
</manifest>
XMLEOF

# Sync
for i in 1 2; do /opt/crave/resync.sh; done

# ========================================================
# APPLYING PATCHES FROM BIMUAFAQ REPO
# ========================================================
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

# ========================================================
# FIX: THE MAGISK-FREE BOOT FIXES (RMX1805 SPECIFIC)
# ========================================================

# 1. Fix the AVB typo (--flag to --flags) in official trees
sed -i 's/--flag 2/--flags 2/g' device/oppo/RMX1805/BoardConfig.mk

# 2. Match Security Patch Level to bypass rollback protection
sed -i 's/PLATFORM_SECURITY_PATCH := [0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}/PLATFORM_SECURITY_PATCH := 2022-01-01/g' build/make/core/version_defaults.mk || true
echo "PLATFORM_SECURITY_PATCH := 2022-01-01" >> device/oppo/RMX1805/BoardConfig.mk

# 3. Clean fstab from AVB checks (Essential for non-Magisk boot)
sed -i 's/,avb//g' device/oppo/RMX1805/rootdir/etc/fstab.qcom || true

# ========================================================

source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka bacon
