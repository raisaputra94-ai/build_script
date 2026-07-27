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
  <project name="ninja-ninja-arch/android_device_realme_RMX1805" path="device/realme" remote="gh" revision="main" />
  <project name="ninja-ninja-arch/android_vendor_realme_RMX1805" path="vendor/realme/RMX1805" remote="gh" revision="test11" />
  <project name="ninja-ninja-arch/kernel_realme_RMX1805_oss" path="kernel/realme/RMX1805" remote="gh" revision="12" />
</manifest>
XMLEOF

# Sync
for i in 1 2; do /opt/crave/resync.sh; done

# rm device/realme/RMX1805/vendorsetup.sh
# PATCH_URL="https://raw.githubusercontent.com/bimuafaq/local_manifests/main/lineageos-18.1/patches"

# apply_patch() {
#     local dir=$1
#     local patch=$2
#     echo "Applying $patch to $dir..."
#     curl -sL "$PATCH_URL/$patch" -o "$patch"
#     pushd "$dir" > /dev/null
#     git am --3way < "../../$patch" || (git am --abort && echo "Failed to apply $patch")
#     popd > /dev/null
#     rm "$patch"
# }

# apply_patch "build/make" "build.patch"
# apply_patch "system/core" "core.patch"
# apply_patch "external/selinux" "selinux.patch"
# apply_patch "system/sepolicy" "sepolicy.patch"

DEVICE_MK=device/realme/RMX1805/device.mk

sed -i 's/\\[[:space:]]\+$/\\/' "$DEVICE_MK"

# Verify the fix actually applied; abort early rather than fail 40 min into a build.
if grep -qP '\\\s+$' "$DEVICE_MK"; then
    echo "ERROR: trailing whitespace after backslash still present in $DEVICE_MK:"
    grep -nP '\\\s+$' "$DEVICE_MK"
    exit 1
fi
echo "OK: device.mk line-continuation typo patched."

# Sanity-check every makefile in the device tree for the same class of bug.
if grep -rnP '\\\s+$' device/realme/RMX1805/ --include='*.mk' ; then
    echo "WARNING: other makefiles have trailing whitespace after a backslash (above)."
fi

source build/envsetup.sh
lunch lineage_RMX1805-userdebug
mka installclean
rm -rf out/target/product/RMX1805
mka bacon
