#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# Install compatibility libraries. Deliberately NO '|| true' here: under
# 'set -e' a failed download aborts now with a clear error instead of dying
# 3 hours into the build with a missing-library mystery. (dpkg -i over an
# already-installed package is a harmless reinstall, so reused machines
# are fine.)
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb
sudo dpkg -i libtinfo5_6.3-2_amd64.deb
rm -f libtinfo5_6.3-2_amd64.deb

wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb
sudo dpkg -i libncurses5_6.3-2_amd64.deb
rm -f libncurses5_6.3-2_amd64.deb

# Clean stale state from any previous run BEFORE repo init. Crave reuses the
# workspace, so .repo/local_manifests may still hold the old manifest with the
# duplicate sepolicy path — repo init aborts on it before this script ever
# gets to rewrite it. (This is what killed build 303966 in under a minute.)
rm -rf \
  device/oppo vendor/oppo kernel/oppo \
  device/realme vendor/realme kernel/realme \
  .repo/local_manifests .repo/local_manifest.xml

mkdir -p .repo/local_manifests
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />
  <project name="ninja-ninja-arch/android_device_realme_RMX1805" path="device/realme" remote="gh" revision="main" />
  <project name="ninja-ninja-arch/android_vendor_realme_RMX1805" path="vendor/realme/RMX1805" remote="gh" revision="test11" />
  <project name="ninja-ninja-arch/kernel_realme_RMX1805_oss" path="kernel/realme/RMX1805" remote="gh" revision="12" />
  <!-- NOTE: device/qcom/sepolicy-legacy-um is already in the LineageOS-Revived
       base manifest (snippets/lineage.xml) at revision lineage-18.1-legacy-um.
       Do NOT add it here: a duplicate path aborts the sync. -->
</manifest>
XMLEOF

repo init \
  -u https://github.com/LineageOS-Revived/android.git \
  -b lineage-18.1 \
  --depth=1 \
  --git-lfs

# Sync sources. The '||' retry is deliberate: under 'set -e' a for-loop would
# abort on the first failure without ever retrying, so a transient network
# error during the multi-hour sync would waste the whole queue. Retry once.
/opt/crave/resync.sh || /opt/crave/resync.sh

# Fail fast if anything didn't sync: a missing tree here means lunch will die
# with a confusing roomservice error. Better to stop now with a clear message.
for f in device/realme/RMX1805/lineage_RMX1805.mk \
         device/realme/RMX1805/AndroidProducts.mk \
         vendor/realme/RMX1805/BoardConfigVendor.mk \
         kernel/realme/RMX1805/Makefile \
         device/qcom/sepolicy-legacy-um/SEPolicy.mk \
         vendor/lineage/config/common_full_phone.mk; do
  if [[ ! -e "$f" ]]; then
    echo "ERROR: expected source missing after sync: $f" >&2
    exit 1
  fi
done
echo "All device sources present."

# Fix a make syntax bug in the ninja device tree: device.mk line 395 is
# "PRODUCT_PACKAGES += \ " with a trailing space after the line-continuation
# backslash. Make does not treat "\ " as a continuation, so lunch dies with
# "device.mk:396: error: missing separator". This is what killed build 304057
# at 2m38s. Strip trailing whitespace after backslashes (idempotent; a no-op
# once fixed upstream), then fail fast if the broken line is still there.
sed -i 's/\\ $/\\/' device/realme/RMX1805/device.mk
if grep -qE '\\ $' device/realme/RMX1805/device.mk; then
  echo "ERROR: broken line continuation still present in device/realme/RMX1805/device.mk" >&2
  exit 1
fi
echo "device.mk line-continuation fix applied."

# Fix a kernel Kconfig bug: drivers/Kconfig unconditionally sources
# "drivers/kernelsu/Kconfig", but that directory was never pushed to the
# kernel repo's branch 12 (no .gitmodules either) -- kconfig aborts the
# defconfig step with 'can't open file "drivers/kernelsu/Kconfig"'.
# This is what killed build 304178 at 6%. Safe to drop: the defconfig does
# not enable CONFIG_KSU, and drivers/Makefile only builds it as
# obj-$(CONFIG_KSU). (Idempotent; a no-op once fixed upstream.)
sed -i '\|^source "drivers/kernelsu/Kconfig"$|d' kernel/realme/RMX1805/drivers/Kconfig
if grep -q 'drivers/kernelsu/Kconfig' kernel/realme/RMX1805/drivers/Kconfig; then
  echo "ERROR: kernelsu Kconfig source still present in kernel drivers/Kconfig" >&2
  exit 1
fi
echo "kernel Kconfig kernelsu fix applied."

# Fresh output for this device so no stale artifacts are reused.
rm -rf out/target/product/RMX1805

# Clear soong's source-finder cache. soong_ui caches the tree scan in
# out/.module_paths/files.db and derives out/.module_paths/AndroidProducts.mk.list
# from it; lunch reads that list to locate lineage_RMX1805.mk. Because this
# script deletes and re-syncs the device/vendor/kernel trees on every run
# (Crave reuses the workspace), a stale cache makes lunch fail with
# 'Can not locate config makefile for product "lineage_RMX1805"' even though
# the tree synced fine. This dir is fully regenerable -- soong_ui rebuilds it
# on the next lunch. (This is what killed the 01:59 run after 304057 worked.)
rm -rf out/.module_paths

source build/envsetup.sh

# Build as userdebug.
lunch lineage_RMX1805-userdebug
mka bacon

# ---------------------------------------------------------------------------
# Sign the ROM with private release keys.
# Keys are generated once and reused on later runs. BACK UP ~/.android-certs
# somewhere safe: future updates MUST be signed with the SAME keys, or they
# will refuse to install over this build.
# ---------------------------------------------------------------------------
KEYS_DIR="$HOME/.android-certs"
mkdir -p "$KEYS_DIR"

if [[ ! -f "$KEYS_DIR/releasekey.pk8" ]]; then
  echo "Generating new private release keys in $KEYS_DIR ..."
  KEY_SUBJECT='/C=US/ST=California/L=Mountain View/O=RMX1805/OU=RMX1805/CN=RMX1805/emailAddress=android@android.com'
  for key in releasekey platform shared media networkstack; do
    ./development/tools/make_key "$KEYS_DIR/$key" "$KEY_SUBJECT"
  done
  echo "Keys generated. Back them up before you lose this machine."
else
  echo "Reusing existing release keys in $KEYS_DIR."
fi

# bacon's zip is test-key signed; rebuild target files and sign them properly.
mka target-files-package

TF_ZIP="$(ls -t out/target/product/RMX1805/obj/PACKAGING/target_files_intermediates/*-target_files-*.zip | head -n1)"
# The ls|head pipe masks ls failures under 'set -e' (pipe status is head's),
# so verify explicitly instead of signing an empty filename hours in.
[[ -f "$TF_ZIP" ]] || { echo "ERROR: no target_files zip found after target-files-package" >&2; exit 1; }
echo "Signing target files: $TF_ZIP"

SIGNED_TF="out/target/product/RMX1805/signed-target_files.zip"
SIGNED_OTA="out/target/product/RMX1805/lineage-18.1-$(date +%Y%m%d)-UNOFFICIAL-RMX1805-signed.zip"

./build/tools/releasetools/sign_target_files_apks -o -d "$KEYS_DIR" "$TF_ZIP" "$SIGNED_TF"
./build/tools/releasetools/ota_from_target_files -k "$KEYS_DIR/releasekey" "$SIGNED_TF" "$SIGNED_OTA"

echo "Signed ROM ready: $SIGNED_OTA"
