#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# === v1: RMX1805-org tree (v0 + releasetools AVB salt fix) ===
# v1 adds one patch vs v0: common.py's AVB salt sha256(fingerprint) crashed
# sign_target_files_apks in build 306563 ("Strings must be encoded before
# hashing") — the build had SUCCEEDED; only signing died. See the patch
# block below. Everything else is identical to v0.
#
# After v27 (ninja tree + stock vendor) dropped to fastboot even with the
# proven 2022 boot.img swapped in — exonerating the kernel and proving the
# ninja system cannot boot on the stock vendor — we reset to v0 on the
# official RMX1805 org tree (github.com/RMX1805), which is what the fully
# working 2022 unofficial ROM (18.1-20220208-UNOFFICIAL-RMX1805) was built
# from.
#
# Why the org tree should work where ninja's didn't:
#  - Prebuilt kernel, md5 181bc0390f877a8f288c3663adc28faa, BYTE-IDENTICAL to
#    the 2022 ROM's kernel and the stock A.71 kernel. No DTB lottery, no
#    WLAN module issues — the proven 4.9.112 with correct DTBs.
#  - device.mk ships NO camera provider (only Snap). The stock vendor
#    declares/provides camera.provider v2.4 legacy/0 itself — exactly the
#    2022 architecture. (Ninja's source-built generic provider enumerated
#    0 cameras against the OPPO stack.)
#  - system.prop already sets rild.libpath=/vendor/lib64/libril-qc-qmi-1.so
#    + rild.libargs=-d /dev/smd0 — the proven IMEI-working RIL path.
#  - BOARD_KERNEL_CMDLINE already has firmware_class.path=/vendor/firmware_mnt/image
#    (WCNSS firmware lives on the firmware partition) and
#    androidboot.selinux=permissive (bring-up; enforcing comes later).
#  - Light.cpp ALREADY scales brightness (brightness * maxBrightness / 0xFF)
#    — no backlight bug.
#  - AVB is enabled (BOARD_AVB_ENABLE := true, test key). The 2022 ROM was
#    built with this exact config and boots, so AVB is NOT disabled here.
#    (Disabling it did not fix the org tree's historical fastboot drop
#    anyway — AVB was never established as the cause.)
#
# v0 makes ZERO source patches to the org tree: it is built as-is, the way
# the 2022 ROM was. Only build-system fixes (releasetools, device.mk syntax)
# and the standard signing infrastructure are applied.
#
# Flash model: flash the full signed zip via TWRP (system + built vendor +
# boot + dtbo). The org's vendor blobs (vendor/oppo/RMX1805/proprietary/)
# plus the HALs built from device.mk should produce a complete vendor.img.
# FALLBACK: if it does not boot, fastboot flash the stock A.71 vendor.img
# over the built vendor (fastboot flash vendor stock_vendor.img) — the 2022
# ROM ran on the stock vendor, so that combination is proven.

# Install compatibility libraries. Deliberately NO '|| true' here: under
# 'set -e' a failed download aborts now with a clear error instead of dying
# 3 hours into the build with a missing-library mystery.
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb
sudo dpkg -i libtinfo5_6.3-2_amd64.deb
rm -f libtinfo5_6.3-2_amd64.deb

wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb
sudo dpkg -i libncurses5_6.3-2_amd64.deb
rm -f libncurses5_6.3-2_amd64.deb

# Clean stale state from any previous run BEFORE repo init. Crave reuses the
# workspace, so .repo/local_manifests may still hold the old manifest —
# repo init aborts on a stale manifest before this script ever gets to
# rewrite it. (This is what killed build 303966 in under a minute.)
# We clean BOTH oppo and realme paths: v0 uses oppo, but a leftover realme
# tree from the ninja builds would confuse lunch/soong.
rm -rf \
  device/oppo vendor/oppo kernel/oppo \
  device/realme vendor/realme kernel/realme \
  .repo/local_manifests .repo/local_manifest.xml

mkdir -p .repo/local_manifests
cat > .repo/local_manifests/rmx1805.xml << 'XMLEOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="gh" fetch="https://github.com/" />
  <project name="RMX1805/device_oppo_RMX1805" path="device/oppo/RMX1805" remote="gh" revision="lineage-18.1" />
  <project name="RMX1805/vendor_oppo" path="vendor/oppo" remote="gh" revision="lineage-18.1" />
  <!-- NOTE: device/qcom/sepolicy-legacy-um is already in the LineageOS-Revived
       base manifest (snippets/lineage.xml) at revision lineage-18.1-legacy-um.
       Do NOT add it here: a duplicate path aborts the sync. -->
  <!-- NOTE: no kernel project — the org tree uses a prebuilt kernel at
       device/oppo/RMX1805/prebuilt/kernel (md5-verified below). -->
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
for f in device/oppo/RMX1805/lineage_RMX1805.mk \
         device/oppo/RMX1805/AndroidProducts.mk \
         device/oppo/RMX1805/BoardConfig.mk \
         device/oppo/RMX1805/device.mk \
         vendor/oppo/RMX1805/RMX1805-vendor.mk \
         device/qcom/sepolicy-legacy-um/SEPolicy.mk \
         vendor/lineage/config/common_full_phone.mk; do
  if [[ ! -e "$f" ]]; then
    echo "ERROR: expected source missing after sync: $f" >&2
    exit 1
  fi
done
echo "All device sources present."

# Verify the prebuilt kernel is the proven one. The org tree's prebuilt/kernel
# must be byte-identical (md5 181bc0390f877a8f288c3663adc28faa) to the 2022
# ROM's kernel and the stock A.71 kernel — that is the entire basis for
# trusting this tree's WiFi/BT/camera/DTB behavior. If the org ever swaps the
# prebuilt kernel, stop here instead of building on an unknown binary.
EXPECTED_KERN_MD5="181bc0390f877a8f288c3663adc28faa"
KERN=device/oppo/RMX1805/prebuilt/kernel
if [[ ! -f "$KERN" ]]; then
  echo "ERROR: prebuilt kernel missing: $KERN" >&2
  exit 1
fi
KERN_MD5="$(md5sum "$KERN" | cut -d' ' -f1)"
if [[ "$KERN_MD5" != "$EXPECTED_KERN_MD5" ]]; then
  echo "ERROR: prebuilt kernel md5 mismatch: got $KERN_MD5, expected $EXPECTED_KERN_MD5" >&2
  echo "The org tree's kernel changed — do not build blind on an unknown binary." >&2
  exit 1
fi
echo "Prebuilt kernel verified (md5 $KERN_MD5, matches 2022/stock)."

# Verify the prebuilt dtbo.img is present.
if [[ ! -f device/oppo/RMX1805/prebuilt/dtbo.img ]]; then
  echo "ERROR: prebuilt dtbo.img missing: device/oppo/RMX1805/prebuilt/dtbo.img" >&2
  exit 1
fi
echo "Prebuilt dtbo.img present."

# Guard against a make syntax bug class: a trailing space after a
# line-continuation backslash in device.mk ("PRODUCT_PACKAGES += \ ") is not
# treated as a continuation, and lunch dies with "missing separator".
# (This killed build 304057 on the ninja tree.) Strip and fail fast if the
# broken line survives. Idempotent.
sed -i 's/\\ $/\\/' device/oppo/RMX1805/device.mk
if grep -qE '\\ $' device/oppo/RMX1805/device.mk; then
  echo "ERROR: broken line continuation still present in device/oppo/RMX1805/device.mk" >&2
  exit 1
fi
echo "device.mk line-continuation check passed."

# Fix a Python 3 bug in AOSP releasetools: add_img_to_target_files.py's
# AddVendor() opens its output_sink() file in TEXT mode ("w") but writes
# binary image data to it. Under Python 3 this dies with "TypeError: write()
# argument must be str, not bytes". (This killed build 305847 at the end of
# sign_target_files_apks.) The bug exists in AOSP android11-release itself,
# so patch it post-sync. Idempotent.
ADD_IMG=build/make/tools/releasetools/add_img_to_target_files.py
sed -i 's|open(os.path.join(OPTIONS.input_tmp, "VENDOR", fn), "w")|open(os.path.join(OPTIONS.input_tmp, "VENDOR", fn), "wb")|' "$ADD_IMG"
if grep -q 'os.path.join(OPTIONS.input_tmp, "VENDOR", fn), "w")' "$ADD_IMG"; then
  echo "ERROR: AddVendor output_sink still opens in text mode in $ADD_IMG" >&2
  exit 1
fi
echo "releasetools AddVendor binary-mode fix applied."

# Fix ANOTHER Python 3 bug in AOSP releasetools (build 306563): common.py's
# LoadInfoDict computes the AVB salt with sha256(fingerprint) where
# 'fingerprint' is a str — hashlib requires bytes, so it dies with
# "TypeError: Strings must be encoded before hashing". This only triggers
# when AVB is enabled (the org tree sets BOARD_AVB_ENABLE := true; ninja's
# tree did not, which is why v27 signing never hit it). The build itself had
# already SUCCEEDED — the crash was purely in sign_target_files_apks.
# One-line fix: encode the fingerprint. Idempotent.
COMMON_PY=build/make/tools/releasetools/common.py
sed -i 's|sha256(fingerprint)|sha256(fingerprint.encode())|' "$COMMON_PY"
if grep -q 'sha256(fingerprint)' "$COMMON_PY"; then
  echo "ERROR: AVB salt sha256 still unencoded in $COMMON_PY" >&2
  exit 1
fi
echo "releasetools AVB salt encode fix applied."

# Fresh output for this device so no stale artifacts are reused.
rm -rf out/target/product/RMX1805

# Clear soong's source-finder cache. soong_ui caches the tree scan in
# out/.module_paths/files.db; because this script deletes and re-syncs the
# device/vendor trees on every run (Crave reuses the workspace), a stale
# cache makes lunch fail with 'Can not locate config makefile for product
# "lineage_RMX1805"' even though the tree synced fine. Fully regenerable.
rm -rf out/.module_paths

source build/envsetup.sh

# Build as userdebug (adb root for testing; the 2022 ROM was user, but
# userdebug is strictly more useful for bring-up and costs nothing here).
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

# Require the FULL key set: a partial generation from a previously failed run
# is worse than none, because sign_target_files_apks would fail cryptically
# much later.
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
    # NOTE: do NOT use development/tools/make_key here. It creates its named
    # pipes with mknod(1), which requires root (CAP_MKNOD) and fails for the
    # unprivileged build user. Plain openssl produces the identical
    # .pk8 (DER) + .x509.pem format.
    KEY_TMP="$KEYS_DIR/.tmp-$key.pem"
    openssl genrsa -f4 -out "$KEY_TMP" 2048 || {
      echo "ERROR: openssl genrsa failed for '$key'" >&2; rm -f "$KEY_TMP"; exit 1; }
    openssl pkcs8 -topk8 -inform PEM -outform DER -in "$KEY_TMP" \
      -out "$KEYS_DIR/$key.pk8" -nocrypt || {
      echo "ERROR: openssl pkcs8 failed for '$key'" >&2; rm -f "$KEY_TMP"; exit 1; }
    openssl req -new -x509 -sha256 -key "$KEY_TMP" \
      -out "$KEYS_DIR/$key.x509.pem" -days 10000 -subj "$KEY_SUBJECT" || {
      echo "ERROR: openssl req failed for '$key'" >&2; rm -f "$KEY_TMP"; exit 1; }
    rm -f "$KEY_TMP"
    [[ -s "$KEYS_DIR/$key.pk8" && -s "$KEYS_DIR/$key.x509.pem" ]] || {
      echo "ERROR: $key key files missing or empty after generation" >&2; exit 1; }
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

# Python 3.12 removed the 'imp' module, but 18.1's releasetools still do
# 'import imp' — provide a minimal imp shim through PYTHONPATH for the two
# releasetools invocations below. The build itself is unaffected.
IMP_SHIM_DIR="$PWD/.imp_shim"
mkdir -p "$IMP_SHIM_DIR"
cat > "$IMP_SHIM_DIR/imp.py" <<'PYEOF'
"""Minimal 'imp' replacement for Python 3.12+ (imp was removed in 3.12).
Implements only what build/tools/releasetools/common.py uses:
  imp.find_module(name, path) -> (file, pathname, description)
  imp.load_module(name, file, pathname, description) -> module
"""
import importlib.util
import os
import sys

PY_SOURCE = 1
PKG_DIRECTORY = 5

def find_module(name, path=None):
    if path is None:
        path = sys.path
    for entry in path:
        pkg_dir = os.path.join(entry, name)
        if os.path.isdir(pkg_dir) and os.path.isfile(
                os.path.join(pkg_dir, "__init__.py")):
            return (None, pkg_dir, ("", "", PKG_DIRECTORY))
        mod_file = os.path.join(entry, name + ".py")
        if os.path.isfile(mod_file):
            return (open(mod_file, "r"), mod_file, (".py", "r", PY_SOURCE))
    raise ImportError("No module named %s" % name)

def load_module(name, file, pathname, description):
    suffix, mode, kind = description
    if file is not None:
        try:
            file.close()
        except Exception:
            pass
    if name in sys.modules:
        return sys.modules[name]
    if kind == PKG_DIRECTORY:
        init_file = os.path.join(pathname, "__init__.py")
        spec = importlib.util.spec_from_file_location(
            name, init_file, submodule_search_locations=[pathname])
    else:
        spec = importlib.util.spec_from_file_location(name, pathname)
    if spec is None or spec.loader is None:
        raise ImportError("cannot load %s from %s" % (name, pathname))
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module
PYEOF
export PYTHONPATH="$IMP_SHIM_DIR${PYTHONPATH:+:$PYTHONPATH}"

# -p out/host/linux-x86 is REQUIRED: common.py defaults search_path to
# <script-dir>/.., but build/tools/releasetools/* are symlinks into
# build/make/tools/, so realpath() resolves to the wrong tree and signapk.jar
# is not found there. The jar lives in the host out dir.
./build/tools/releasetools/sign_target_files_apks -o -p out/host/linux-x86 -d "$KEYS_DIR" "$TF_ZIP" "$SIGNED_TF"
./build/tools/releasetools/ota_from_target_files -p out/host/linux-x86 -k "$KEYS_DIR/releasekey" "$SIGNED_TF" "$SIGNED_OTA"

echo "Signed ROM ready: $SIGNED_OTA"
echo "Flash: TWRP install the signed zip, factory reset, reboot."
echo "If it does not boot: fastboot flash vendor <stock A.71 vendor.img> over the built vendor and reboot."
