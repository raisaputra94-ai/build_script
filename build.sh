#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# ---------------------------------------------------------------------------
# Upload a file to PixelDrain and print the share URL.
# Never fails the build: any upload problem is a warning only; the zip
# stays on the devspace either way.
# ---------------------------------------------------------------------------
pixeldrain_upload() {
  local file="$1" label="${2:-$(basename "$file")}"
  if [[ ! -f "$file" ]]; then
    echo "WARNING: PixelDrain upload skipped ($label): not found: $file" >&2
    return 0
  fi
  local size
  size=$(du -h "$file" 2>/dev/null | cut -f1 || true)
  echo "Uploading $label to PixelDrain: $(basename "$file") (${size:-?}) ..."
  local resp
  resp=$(curl -sS --retry 2 --retry-delay 5 -X PUT --upload-file "$file" \
    "https://pixeldrain.com/api/file/$(basename "$file")") || {
      echo "WARNING: PixelDrain upload failed ($label): curl error, zip remains on devspace" >&2
      return 0
  }
  local file_id=""
  if command -v jq >/dev/null 2>&1; then
    file_id=$(echo "$resp" | jq -r '.id // empty' 2>/dev/null || true)
  fi
  if [[ -z "$file_id" ]]; then
    file_id=$(echo "$resp" | grep -o '"id":"[^"]*"' | head -n1 | cut -d'"' -f4)
  fi
  if [[ -n "$file_id" ]]; then
    echo "PixelDrain [$label]: https://pixeldrain.com/u/$file_id"
  else
    echo "WARNING: PixelDrain upload ($label) unexpected API response: $resp" >&2
  fi
  return 0
}

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

# Fix missing Himax touchscreen firmware: himax_ic_incell_core.c includes
# "himax_firmware_tcl.i" under HX_ZERO_FLASH, but that file was never pushed
# to the kernel repo (branch 12). Fetch the real 340KB firmware from
# LinuxGuy312's kernel tree, which carries the same driver with the file
# present. Only fetch if missing, so a future upstream push wins.
# (This killed build 304417 at 44%.)
HX_FW=kernel/realme/RMX1805/drivers/input/touchscreen/himax_hx83102d/himax_firmware_tcl.i
if [[ ! -f "$HX_FW" ]]; then
  wget -q -O "$HX_FW" https://raw.githubusercontent.com/LinuxGuy312/android_kernel_realme_RMX1805/ArcticFox/drivers/input/touchscreen/himax_hx83102d/himax_firmware_tcl.i
  [[ -s "$HX_FW" ]] || { echo "ERROR: failed to download himax firmware" >&2; exit 1; }
  echo "himax firmware fetched."
else
  echo "himax firmware file present upstream, fetch not needed."
fi

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

# Upload the bacon zip immediately: if the signing stage below ever fails
# again (build 304624 died in make_key AFTER bacon completed), the ROM is
# still retrievable via this link instead of SSH.
BACON_ZIP=$(ls -t out/target/product/RMX1805/lineage-*-UNOFFICIAL-RMX1805.zip 2>/dev/null | head -n1 || true)
pixeldrain_upload "$BACON_ZIP"

# ---------------------------------------------------------------------------
# Sign the ROM with private release keys.
# Keys are generated once and reused on later runs. BACK UP ~/.android-certs
# somewhere safe: future updates MUST be signed with the SAME keys, or they
# will refuse to install over this build.
# ---------------------------------------------------------------------------
KEYS_DIR="$HOME/.android-certs"
mkdir -p "$KEYS_DIR"

# Require the FULL key set: a partial generation from a previously failed run
# (build 304624 died inside make_key for the very first key) is worse than
# none, because sign_target_files_apks would fail cryptically much later.
ALL_KEYS_PRESENT=true
for key in releasekey platform shared media networkstack; do
  if [[ ! -s "$KEYS_DIR/$key.pk8" || ! -s "$KEYS_DIR/$key.x509.pem" ]]; then
    ALL_KEYS_PRESENT=false
  fi
done

if [[ "$ALL_KEYS_PRESENT" != true ]]; then
  echo "Generating new private release keys in $KEYS_DIR ..."
  command -v openssl >/dev/null 2>&1 || { echo "ERROR: 'openssl' not found; cannot generate release keys" >&2; exit 1; }
  # Start clean: drop any partial keys left by an earlier failed run.
  rm -f "$KEYS_DIR"/releasekey.pk8 "$KEYS_DIR"/platform.pk8 "$KEYS_DIR"/shared.pk8 \
        "$KEYS_DIR"/media.pk8 "$KEYS_DIR"/networkstack.pk8 "$KEYS_DIR"/*.x509.pem
  KEY_SUBJECT='/C=US/ST=California/L=Mountain View/O=RMX1805/OU=RMX1805/CN=RMX1805/emailAddress=android@android.com'
  for key in releasekey platform shared media networkstack; do
    echo "--- generating key: $key ---"
    # </dev/null: make_key prompts for a key password; feed it EOF so it
    # deterministically uses no password instead of hanging on stdin.
    ./development/tools/make_key "$KEYS_DIR/$key" "$KEY_SUBJECT" < /dev/null || {
      echo "ERROR: make_key failed for '$key'; check openssl and free disk space" >&2
      exit 1
    }
    [[ -s "$KEYS_DIR/$key.pk8" && -s "$KEYS_DIR/$key.x509.pem" ]] || {
      echo "ERROR: $key key files missing or empty after make_key" >&2
      exit 1
    }
  done
  echo "Keys generated. BACK THEM UP before you lose this machine."
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
pixeldrain_upload "$SIGNED_OTA"
