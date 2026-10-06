#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# Install compatibility libraries
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb && \
  sudo dpkg -i libtinfo5_6.3-2_amd64.deb && \
  rm -f libtinfo5_6.3-2_amd64.deb || true

wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb && \
  sudo dpkg -i libncurses5_6.3-2_amd64.deb && \
  rm -f libncurses5_6.3-2_amd64.deb || true

repo init \
  -u https://github.com/LineageOS-Revived/android.git \
  -b lineage-18.1 \
  --depth=1 \
  --git-lfs

# Remove old device-specific sources and manifests.
rm -rf \
  device/oppo vendor/oppo kernel/oppo \
  device/realme vendor/realme kernel/realme \
  .repo/local_manifests

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

# Sync sources.
for i in 1 2; do
  /opt/crave/resync.sh
done

# Fail fast if anything didn't sync: a missing tree here means lunch will die
# with a confusing roomservice error. Better to stop now with a clear message.
for f in device/realme/RMX1805/lineage_RMX1805.mk \
         vendor/realme/RMX1805/BoardConfigVendor.mk \
         kernel/realme/RMX1805/Makefile \
         device/qcom/sepolicy-legacy-um/SEPolicy.mk; do
  if [[ ! -e "$f" ]]; then
    echo "ERROR: expected source missing after sync: $f" >&2
    exit 1
  fi
done
echo "All device sources present."

# Fresh output for this device so no stale artifacts are reused.
rm -rf out/target/product/RMX1805

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
echo "Signing target files: $TF_ZIP"

SIGNED_TF="out/target/product/RMX1805/signed-target_files.zip"
SIGNED_OTA="out/target/product/RMX1805/lineage-18.1-$(date +%Y%m%d)-UNOFFICIAL-RMX1805-signed.zip"

./build/tools/releasetools/sign_target_files_apks -o -d "$KEYS_DIR" "$TF_ZIP" "$SIGNED_TF"
./build/tools/releasetools/ota_from_target_files -k "$KEYS_DIR/releasekey" "$SIGNED_TF" "$SIGNED_OTA"

echo "Signed ROM ready: $SIGNED_OTA"
