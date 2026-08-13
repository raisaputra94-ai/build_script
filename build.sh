#!/bin/bash
# AI SLOP
# ArrowOS 11.0 build script for Oppo/Realme RMX1805 (realme 2 / realme C1)
#
#   ROM     : https://github.com/ArrowOS/android_manifest        -b arrow-11.0
#   Device  : https://github.com/altorgtohostshit/device_oppo_RMX1805 -b lineage-18.1
#   Vendor  : https://github.com/RMX1805/vendor_oppo             -b lineage-18.1
#
# The device tree is a LineageOS 18.1 tree, so this script syncs Arrow and then
# patches the tree into an Arrow-compatible product (arrow_RMX1805). All patches
# are idempotent -- re-running the script is safe.
#
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# --- VANILLA build: no GMS / no GApps ---------------------------------------
# ARROW_GAPPS=true is what makes vendor/arrow inherit vendor/gapps and flips the
# zip type to GAPPS. Force it off in case the build host exports it.
export ARROW_GAPPS=false
unset WITH_GMS TARGET_GAPPS_ARCH GAPPS_VARIANT WITH_GAPPS

DEVICE=RMX1805
DEVICE_PATH=device/oppo/$DEVICE

# ---------------------------------------------------------------------------
# Host libs (needed by the prebuilt toolchains on newer Ubuntu images)
# ---------------------------------------------------------------------------
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb && \
 sudo dpkg -i libtinfo5_6.3-2_amd64.deb && rm -f libtinfo5_6.3-2_amd64.deb || true
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb && \
 sudo dpkg -i libncurses5_6.3-2_amd64.deb && rm -f libncurses5_6.3-2_amd64.deb || true

# ---------------------------------------------------------------------------
# Manifest
# ---------------------------------------------------------------------------
repo init -u https://github.com/ArrowOS/android_manifest.git -b arrow-11.0 --depth=1 --git-lfs

# Clean up leftovers from any previous (LineageOS) run
rm -rf device/oppo vendor/oppo kernel/oppo device/realme vendor/realme kernel/realme
rm -rf .repo/local_manifests

mkdir -p .repo/local_manifests
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />

  <!-- Device tree (LineageOS 18.1 tree, patched to Arrow below) -->
  <project name="altorgtohostshit/device_oppo_RMX1805" path="device/oppo/RMX1805" remote="gh" revision="lineage-18.1" />

  <!-- Vendor blobs. NOTE: this repo already contains a top-level RMX1805/
       directory, so it must land in vendor/oppo, NOT vendor/oppo/RMX1805. -->
  <project name="RMX1805/vendor_oppo" path="vendor/oppo" remote="gh" revision="lineage-18.1" />

  <!-- VANILLA build: don't even sync the GApps vendor tree. -->
  <remove-project name="android_vendor_gapps" />
</manifest>
XMLEOF

# No kernel repo on purpose: the device tree ships a prebuilt kernel + dtbo
# (prebuilt/kernel, prebuilt/dtbo.img) and Arrow's build/tasks/kernel.mk falls
# back to TARGET_PREBUILT_KERNEL when no kernel source dir exists.

# ---------------------------------------------------------------------------
# Sync
# ---------------------------------------------------------------------------
for i in 1 2; do /opt/crave/resync.sh; done

# ---------------------------------------------------------------------------
# Patch the Lineage device tree for ArrowOS
# ---------------------------------------------------------------------------
if [ ! -d "$DEVICE_PATH" ]; then
    echo "!! $DEVICE_PATH is missing -- sync failed?"
    exit 1
fi

# 1. Arrow product makefile. The shipped aosp_RMX1805.mk inherits
#    vendor/aosp/common.mk, which does not exist on Arrow, so it is replaced.
cat > $DEVICE_PATH/arrow_$DEVICE.mk << 'MKEOF'
# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_o_mr1.mk)

# Inherit some common ArrowOS stuff.
$(call inherit-product, vendor/arrow/config/common.mk)

# Inherit from RMX1805 device
$(call inherit-product, device/oppo/RMX1805/device.mk)

# Pixel charger animation
TARGET_INCLUDE_PIXEL_CHARGER := true

# Boot animation
TARGET_SCREEN_WIDTH := 720
TARGET_SCREEN_HEIGHT := 1520
TARGET_BOOT_ANIMATION_RES := 720

# Vanilla build: no GMS / GApps of any kind.
ARROW_GAPPS := false
WITH_GMS := false

## Device identifier. This must come after all inclusions
PRODUCT_DEVICE := RMX1805
PRODUCT_NAME := arrow_RMX1805
PRODUCT_BRAND := oppo
PRODUCT_MANUFACTURER := oppo
PRODUCT_MODEL := realme 2
DEVICE_MAINTAINER := RMX1805
MKEOF

# 2. AndroidProducts.mk -- expose only the Arrow product. Every makefile listed
#    here gets parsed, so aosp_RMX1805.mk (broken on Arrow) must go.
cat > $DEVICE_PATH/AndroidProducts.mk << 'APEOF'
PRODUCT_MAKEFILES := \
	$(LOCAL_DIR)/arrow_RMX1805.mk

COMMON_LUNCH_CHOICES := \
	arrow_RMX1805-userdebug
APEOF
rm -f $DEVICE_PATH/aosp_$DEVICE.mk

# 3. sepolicy paths: Arrow's device/qcom/sepolicy uses the generic/ layout.
sed -i \
    -e 's|device/qcom/sepolicy/private|device/qcom/sepolicy/generic/private|g' \
    -e 's|device/qcom/sepolicy/public|device/qcom/sepolicy/generic/public|g' \
    -e 's|device/qcom/sepolicy/generic/generic/|device/qcom/sepolicy/generic/|g' \
    $DEVICE_PATH/BoardConfig.mk

# 4. lineage.trust@1.0-service has no provider on Arrow 11 -- drop the package.
sed -i '/lineage\.trust@1\.0-service/d' $DEVICE_PATH/device.mk

# 5. Upstream typo: TARGET_COPY_OUT_SYATEM -> TARGET_COPY_OUT_SYSTEM
sed -i 's/TARGET_COPY_OUT_SYATEM/TARGET_COPY_OUT_SYSTEM/g' $DEVICE_PATH/device.mk

# 6. Jelly is the LineageOS browser -- packages/apps/Jelly does not exist in the
#    Arrow manifest at all, so the flag is a dead no-op. The only occurrence is
#    in aosp_RMX1805.mk (already deleted in step 2); this sweeps the whole tree
#    so it stays gone if upstream adds it elsewhere. Arrow ships no Jelly and no
#    replacement browser -- only external/chromium-webview, which is the WebView
#    runtime, not a browser app. The build will have no browser installed.
grep -rl 'TARGET_USE_JELLY\|packages/apps/Jelly\|[^A-Za-z]Jelly' \
    --include='*.mk' $DEVICE_PATH 2>/dev/null | while read -r f; do
    sed -i -e '/TARGET_USE_JELLY/d' \
           -e '/packages\/apps\/Jelly/d' \
           -e '/^[[:space:]]*Jelly[[:space:]]*\\\?$/d' "$f"
done

# 7. Strip any GMS/GApps hooks the device tree might pull in (vanilla build).
sed -i -e '/vendor\/google\/gms\/config\.mk/d' \
       -e '/vendor\/gapps/d' \
       -e '/WITH_GMS/d' \
       $DEVICE_PATH/device.mk $DEVICE_PATH/arrow_$DEVICE.mk 2>/dev/null || true

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
rm -rf out/target/product/$DEVICE

source build/envsetup.sh
lunch arrow_$DEVICE-userdebug
mka installclean
mka bacon

echo
echo "Done. Output:"
ls -lh out/target/product/$DEVICE/*.zip 2>/dev/null || true
