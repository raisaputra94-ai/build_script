#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# === v27: stock-vendor compatibility, revised after the 2022-ROM deep dive ===
# (2026-10-19). The 2022 unofficial ROM (18.1-20220208-UNOFFICIAL-RMX1805,
# system+boot only, stock A.71 vendor at runtime) was downloaded, verified,
# and fully analyzed: kernel 4.9.112-perf+ (byte-identical to the RMX1805-org
# prebuilt kernel), 18 DTBs identical to stock with DTB #0 = SDM450+PMI8950
# carrying qcom,has-pronto-hw, permissive cmdline, NO camera provider in the
# system image (stock vendor declares/provides camera.provider v2.4
# legacy/0), rild.libpath=/vendor/lib64/libril-qc-qmi-1.so (stock vendor
# ships it), ro.treble.enabled=true.
# v26 vs the earlier v25 draft:
#  - DROPPED the PRODUCT_FULL_TREBLE_OVERRIDE removal: the 2022 system is
#    Treble-enabled too and works fine on the stock vendor, so the override
#    is not the differentiator.
#  - KEPT the camera-provider removal (proven: 2022 system ships none).
#  - ADDED system-side RIL props (rild.libpath=qmi-1): ninja's tree sets the
#    hal-qmi path in vendor.prop, which lives in the vendor image we replace
#    with stock. The qmi-1 library is the proven IMEI-working RIL path.
#  - ADDED CONFIG_PRONTO_WLAN=y (built-in): stock's pronto_wlan.ko has
#    vermagic 4.9.112 and cannot load on this 4.9.337 kernel; building the
#    driver in removes the need for any vendor module file.
# v27 adds: firmware_class.path=/vendor/firmware_mnt/image to the kernel
#    cmdline. The 2022 working combo's cmdline carries it; ninja's does not.
#    The WCNSS/WiFi firmware lives on the dedicated firmware partition
#    (mounted at /vendor/firmware_mnt/image), NOT in vendor.img — without
#    this path the built-in driver's firmware load fails. Zero risk: it is
#    a standard kernel parameter, ignored if the path is absent.
# Flash model: flash the built system.img, flash STOCK A.71 vendor.img
# (~/workspace/stock_vendor.img), flash the built boot.img. The generated
# vendor.img is ignored.

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

# DTB single-select (v24): append ONLY sdm450-pmi632.dtb — the RMX1805 DTB.
# Blob-level verification (dtb-single-select-research.md, 2026-10-19):
# - The 4 wildcard DTBs (apq8016-sbc, msm8916-mtp, apq8096-db820c, msm8996-mtp)
#   have no qcom,msm-id; bootloader picks #0 apq8016-sbc which lacks
#   qcom,has-pronto-hw and vfe → WiFi/BT/camera dead.
# - The correct DTB is sdm450-pmi632.dtb: msm-id 0x152 = SDM450 (actual RMX1805
#   SoC), PMI632 PMIC with the RMX1805 OPPO battery profile, has-pronto-hw
#   present, vfe present.
# - v20's CONFIG_ARCH_SDM450 removal would have DELETED this correct DTB.
# Method: CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES (arch/arm64/Kconfig:1209).
# When set, only the named DTBs are appended — zero selection ambiguity, no
# Makefile surgery. (Idempotent.)
DEFCONFIG=kernel/realme/RMX1805/arch/arm64/configs/MSM_18355_msm8953-perf_defconfig
if grep -q '^CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES=' "$DEFCONFIG"; then
  sed -i 's|^CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES=.*|CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="qcom/sdm450-pmi632"|' "$DEFCONFIG"
else
  printf '%s\n' 'CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="qcom/sdm450-pmi632"' >> "$DEFCONFIG"
fi
if ! grep -q '^CONFIG_BUILD_ARM64_APPENDED_DTB_IMAGE_NAMES="qcom/sdm450-pmi632"$' "$DEFCONFIG"; then
  echo "ERROR: DTB single-select did not apply to $DEFCONFIG" >&2
  exit 1
fi
echo "DTB single-select applied: only qcom/sdm450-pmi632.dtb will be appended."
DEFCONFIG=kernel/realme/RMX1805/arch/arm64/configs/MSM_18355_msm8953-perf_defconfig
if ! grep -q "^CONFIG_ARCH_MSM8953=y$" "$DEFCONFIG"; then
  echo "ERROR: CONFIG_ARCH_MSM8953 missing from $DEFCONFIG" >&2
  exit 1
fi
if ! grep -q "^CONFIG_ARCH_QCOM=y$" "$DEFCONFIG"; then
  echo "ERROR: CONFIG_ARCH_QCOM missing from $DEFCONFIG (MSM8953 depends on it!)" >&2
  exit 1
fi
echo "kernel DTB arch fix applied (only MSM8953 DTBs will be built)."

# WiFi driver built-in (v26): the Pronto WLAN driver must NOT be a module.
# The stock A.71 vendor ships pronto_wlan.ko with vermagic 4.9.112-perf+,
# which can never load on this 4.9.337 kernel. Building CONFIG_PRONTO_WLAN=y
# bakes the driver into the kernel — the same "built-in mode" WCNSS probe
# proven working in the v10 BakaSU kernel log — so no vendor module file is
# needed at all. Required for the stock-vendor flash model. (Idempotent.)
if grep -q '^CONFIG_PRONTO_WLAN=m' "$DEFCONFIG"; then
  sed -i 's/^CONFIG_PRONTO_WLAN=m/CONFIG_PRONTO_WLAN=y/' "$DEFCONFIG"
  echo "Pronto WLAN driver set to built-in."
elif grep -q '^CONFIG_PRONTO_WLAN=y' "$DEFCONFIG"; then
  echo "Pronto WLAN driver already built-in."
else
  echo "ERROR: CONFIG_PRONTO_WLAN not found in $DEFCONFIG" >&2
  exit 1
fi
if ! grep -q '^CONFIG_PRONTO_WLAN=y$' "$DEFCONFIG"; then
  echo "ERROR: Pronto WLAN built-in did not apply to $DEFCONFIG" >&2
  exit 1
fi

# WiFi driver is built into the kernel (CONFIG_PRONTO_WLAN=y, see above), so
# WIFI_DRIVER_MODULE_NAME/PATH must NOT be set — the WiFi HAL then uses the
# built-in driver instead of insmod'ing a module. Remove any stale module
# config to avoid confusion. (Idempotent.)
BOARD_MK=device/realme/RMX1805/BoardConfig.mk
if grep -q "^WIFI_DRIVER_MODULE_NAME" "$BOARD_MK"; then
  sed -i '/^WIFI_DRIVER_MODULE_NAME/d; /^WIFI_DRIVER_MODULE_PATH/d' "$BOARD_MK"
  echo "Stale WiFi module config removed from BoardConfig.mk (driver is built-in)."
else
  echo "No WiFi module config present (driver is built-in)."
fi

# Boot permissive by default: the ninja sepolicy has 309+ denials that stall
# boot in enforcing mode. Add androidboot.selinux=permissive to the kernel
# cmdline so the ROM boots without manual boot.img patching. The long-term
# goal is enforcing via sepolicy fixes, but permissive is needed for bring-up.
# (Idempotent.)
if ! grep -q "androidboot.selinux=permissive" "$BOARD_MK"; then
  cat >> "$BOARD_MK" <<'EOF'

# Boot SELinux permissive (sepolicy bring-up pending)
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
EOF
  echo "Permissive cmdline added to BoardConfig.mk."
else
  echo "Permissive cmdline already present."
fi

# Firmware loader path (v27): the WCNSS/WiFi firmware is NOT in vendor.img —
# it lives on the dedicated firmware partition, mounted at
# /vendor/firmware_mnt/image at boot. The 2022 working combo's cmdline sets
# firmware_class.path to it; ninja's cmdline does not, so the built-in
# Pronto driver's firmware request would fail. Mirror the proven value.
# (Idempotent.)
if ! grep -q "firmware_class.path=" "$BOARD_MK"; then
  cat >> "$BOARD_MK" <<'EOF'

# Firmware loader path (WCNSS/WiFi firmware is on the firmware partition)
BOARD_KERNEL_CMDLINE += firmware_class.path=/vendor/firmware_mnt/image
EOF
  echo "firmware_class.path added to BoardConfig.mk."
else
  echo "firmware_class.path already present."
fi
if ! grep -q "firmware_class.path=/vendor/firmware_mnt/image" "$BOARD_MK"; then
  echo "ERROR: firmware_class.path did not apply to $BOARD_MK" >&2
  exit 1
fi

# === Stock-vendor runtime compatibility (v27) ===
# The generated vendor.img is IGNORED at flash time: flash the built
# system.img, the STOCK A.71 vendor.img (~/workspace/stock_vendor.img), and
# the built boot.img. These patches align the system image with the stock
# vendor, mirroring the verified 2022 working combo.
#
# 1. Use the vendor camera HAL, not the source-built generic one. Ninja's
#    device.mk lists android.hardware.camera.provider@2.4-impl and -service
#    in PRODUCT_PACKAGES, building the generic AOSP HAL from source. It
#    enumerates 0 cameras against the OPPO stack. The 2022 system ships NO
#    camera provider at all; the stock vendor declares and provides
#    camera.provider v2.4 legacy/0 itself. Remove both lines. (Idempotent.)
DEVICE_MK=device/realme/RMX1805/device.mk
if grep -q "android.hardware.camera.provider@2.4-impl" "$DEVICE_MK"; then
  sed -i '/android.hardware.camera.provider@2.4-impl/d' "$DEVICE_MK"
  sed -i '/android.hardware.camera.provider@2.4-service/d' "$DEVICE_MK"
  echo "Generic camera provider removed from device.mk (stock vendor HAL will be used)."
else
  echo "Generic camera provider already removed from device.mk."
fi
if grep -q "android.hardware.camera.provider@2.4-impl\|android.hardware.camera.provider@2.4-service" "$DEVICE_MK"; then
  echo "ERROR: camera provider still present in $DEVICE_MK" >&2
  exit 1
fi
#
# 2. RIL props for the stock vendor, system-side. Ninja's tree sets
#    rild.libpath=/vendor/lib64/libril-qc-hal-qmi.so in vendor.prop — but
#    vendor.prop lives in the vendor image we replace with stock. The stock
#    vendor's own build.prop already sets rild.libpath to the qmi-1 library,
#    and the 2022 working system sets the same value system-side, so mirror
#    it here for exact parity with the proven combo (belt and braces — the
#    values are identical, so precedence cannot matter). The qmi-1 RIL path
#    is the proven IMEI-working one (ninja's hal-qmi path shows RIL up but
#    no IMEI).
#    (Idempotent.)
SYSTEM_PROP=device/realme/RMX1805/system.prop
if ! grep -q "^rild.libpath=/vendor/lib64/libril-qc-qmi-1.so" "$SYSTEM_PROP"; then
  cat >> "$SYSTEM_PROP" <<'EOF'

# Stock-vendor RIL compat (mirrors 2022 working combo; stock vendor ships libril-qc-qmi-1.so)
rild.libpath=/vendor/lib64/libril-qc-qmi-1.so
rild.libargs=-d /dev/smd0
EOF
  echo "Stock-vendor RIL props added to system.prop."
else
  echo "Stock-vendor RIL props already present in system.prop."
fi
if ! grep -q "^rild.libpath=/vendor/lib64/libril-qc-qmi-1.so" "$SYSTEM_PROP"; then
  echo "ERROR: RIL props did not apply to $SYSTEM_PROP" >&2
  exit 1
fi

# Fix lights HAL backlight scaling: ninja's Lights.cpp writes the raw 0-255
# brightness value directly, but lcd-backlight/max_brightness is 2047.
# Result: screen stuck dim (255/2047 = 12% brightness). The official RMX1805
# tree scales via (brightness * maxBrightness / 0xFF). Patch the HAL to do
# the same. (Idempotent.)
LIGHTS_CPP=device/realme/RMX1805/lights/Lights.cpp
if ! grep -q "MAX_LCD_BRIGHTNESS" "$LIGHTS_CPP"; then
  # Add the max brightness definition after the kLCDFile definitions
  sed -i 's|static const std::string kLCDFile2 = "/sys/class/backlight/panel0-backlight/brightness";|static const std::string kLCDFile2 = "/sys/class/backlight/panel0-backlight/brightness";\n\nstatic const uint32_t kMaxLcdBrightness = 2047;  // from /sys/class/leds/lcd-backlight/max_brightness|' "$LIGHTS_CPP"
  # Scale the brightness in setLightState (braces required: C++ forbids declarations directly under case)
  sed -i 's|WriteToFile(mBacklightNode, RgbaToBrightness(state.color));|{ uint32_t brightness = RgbaToBrightness(state.color); uint32_t scaled = (brightness * kMaxLcdBrightness) / 0xFF; WriteToFile(mBacklightNode, scaled); }|' "$LIGHTS_CPP"
  echo "Lights HAL backlight scaling fix applied."
else
  echo "Lights HAL backlight scaling already present."
fi

# Fix a Python 3 bug in AOSP releasetools: add_img_to_target_files.py's
# AddVendor() opens its output_sink() file in TEXT mode ("w") but writes
# binary image data (recovery_img.data) to it. The AddSystem() copy of the
# same function correctly uses "wb". Under Python 2 this was harmless;
# under Python 3 it dies with "TypeError: write() argument must be str,
# not bytes". This is what killed build 305847 at the end of
# sign_target_files_apks (all APKs were already signed). The bug exists in
# AOSP android11-release itself, so patch it post-sync. (Idempotent.)
ADD_IMG=build/make/tools/releasetools/add_img_to_target_files.py
sed -i 's|open(os.path.join(OPTIONS.input_tmp, "VENDOR", fn), "w")|open(os.path.join(OPTIONS.input_tmp, "VENDOR", fn), "wb")|' "$ADD_IMG"
if grep -q 'os.path.join(OPTIONS.input_tmp, "VENDOR", fn), "w")' "$ADD_IMG"; then
  echo "ERROR: AddVendor output_sink still opens in text mode in $ADD_IMG" >&2
  exit 1
fi
echo "releasetools AddVendor binary-mode fix applied."

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
    # NOTE: do NOT use development/tools/make_key here. It creates its named
    # pipes with mknod(1), which requires root (CAP_MKNOD) and fails for the
    # unprivileged build user (this killed builds 304624 and 304774). Plain
    # openssl produces the identical .pk8 (DER) + .x509.pem format.
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
# 'import imp' (build/tools/releasetools/common.py:25) — this killed build
# 304900 in sign_target_files_apks with "No module named 'imp'". Provide a
# minimal imp shim (find_module/load_module via importlib) through PYTHONPATH.
# Only used for the two releasetools invocations below; the build itself is
# unaffected.
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
# is not found there (killed build 305649). The jar lives in the host out dir.
./build/tools/releasetools/sign_target_files_apks -o -p out/host/linux-x86 -d "$KEYS_DIR" "$TF_ZIP" "$SIGNED_TF"
./build/tools/releasetools/ota_from_target_files -p out/host/linux-x86 -k "$KEYS_DIR/releasekey" "$SIGNED_TF" "$SIGNED_OTA"

echo "Signed ROM ready: $SIGNED_OTA"
