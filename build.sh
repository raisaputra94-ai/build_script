#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# === v10: RMX1805-org tree (v9 + density via BoardConfig TARGET_SCREEN_DENSITY) ===
# v10 changes only HOW v8/v9 baked the display density: the system.prop
# append is removed, and the script instead retargets BoardConfig.mk's
# existing TARGET_SCREEN_DENSITY := 384 to 360 — the build's own knob
# for ro.sf.lcd_density (the user's pointer). The device-init
# replacement (v9), the SELinux patch, and the gate are unchanged.
#
# === v9: RMX1805-org tree (v8 + device init: fingerprint spoof removed, heap tier added) ===
# v9 adds ONE post-sync step to v8: it replaces the org device tree's
# init/init_msm8953.cpp with a corrected embedded copy — the Pixel 4 XL
# ("coral") fingerprint/description spoof is removed (the build keeps
# its own original build fingerprint) and check_device() gains the
# missing 3072 heap tier. Everything else, including the SELinux patch
# and the in-build gate, is byte-identical to v8/v7.
#
# === v8: RMX1805-org tree (v7 + display density baked in) ===
# v8 changes NO build behavior beyond one property: post-sync it sets
# ro.sf.lcd_density=360 in the org device tree's system.prop (the user's
# display preference, baked in so it survives factory resets — the
# 'wm density 360' runtime override does not). The SELinux patch, the
# in-build gate, and every other step are byte-identical to v7,
# including everything the external review checked.
#
# === v7: RMX1805-org tree (v6 + citation wording only) ===
# v7 changes NO build behavior: the patch, the gate, and every step are
# byte-identical to v6. It only corrects the citation in the v6 note
# below, per the developer's precision point: 969114c is a DOWNSTREAM
# fork revert (topjohnwu's selinux fork); dc4e541 is the real upstream
# commit it reverts. Both are cited wherever the patch is mentioned.
#
# === v6: RMX1805-org tree (v5 + canonical downstream fork revert) ===
# v6 replaces my hand-written drop-perms patch (v4/v5) with the exact
# historical patch the behavior came from, identified by external
# disassembly review 2026-10-22: topjohnwu's selinux fork commit
# 969114cff6ee973f47a3c84cacdef77e504d7bd9 "Revert 'libsepol: Make an
# unknown permission an error in CIL'" (2020-09-04), which reverts
# upstream dc4e54126bf25dea4d51820922ccd1959be68fbc. Semantics: an
# unresolvable permission aborts only for MAP classes; otherwise it is
# logged at WARN and an empty list stands in for the unknown perm (the
# pre-2.8 upstream behavior by James Carter, 2016). AOSP history check
# (git log -S "Use an empty list to represent unknown perm" on
# platform/external/selinux): introduced da51020d (2016), removed by
# dc4e5412 (2019), never re-added — so the 2022 ROM's compiler came from
# a tree carrying this revert, not from vanilla AOSP. The full commit
# (with attribution) is embedded verbatim in the patch block below; it
# applies cleanly to AOSP r46, and a secilc built from r46 + this patch
# reproduces the 2022 compiler's policy output BYTE-IDENTICALLY on both
# the v1 and 2022 policy sets, and passes the v5 in-build gate.
#
# === v5: RMX1805-org tree (v4 + IN-BUILD SELinux gate; flash directly) ===
# v5 makes the fix self-certifying, per the user's call: no external
# verification round-trip. After target-files-package and BEFORE signing,
# the script runs a gate (see the gate block below): the HOST secilc built
# from the same patched external/selinux source must compile THIS build's
# real plat policy plus a probe file that references process:sigcont in
# the exact slot the stock vendor's plat_pub occupies in init's boot-time
# argv. A strict compiler fails there (exit 254) and the script aborts —
# NO signed zip is produced by a build whose compiler lacks the fix. A
# completed v5 run therefore guarantees the fix is in the ROM; flash the
# output directly per the plan at the end of this script.
# Gate validated offline 2026-10-22: strict r46 secilc fails the probe
# with the sigcont error; the patched secilc passes (443,180-byte policy).
#
# === v4: RMX1805-org tree (v3 + SOURCE fix for the secilc compile failure) ===
# v4 replaces v3's binary swap with the true source-level fix. The behavior
# of the 2022 ROM's resolver was identified and reproduced from public AOSP
# r46 source (2026-10-22): in libsepol's __cil_resolve_perms, a permission
# that cannot be resolved (e.g. process:sigcont, dropped from the platform
# class but still referenced by the stock vendor's API-28
# plat_pub_versioned.cil) is DROPPED for non-map classes instead of failing
# the whole policy compile. A secilc built from AOSP r46 + the embedded
# patch below produces a binary policy BYTE-IDENTICAL to the 2022
# compiler's output on both the v1 and the 2022 policy sets (988,503 and
# 895,566 bytes, cmp-verified) — behavioral equivalence proven, no recycled
# binaries. The patch is applied to the synced external/selinux tree after
# repo sync (see the patch block below) with a fail-fast marker check, so
# every build compiles its own working secilc from source. The offline
# compile gate before flashing still applies.
#
# === v3: RMX1805-org tree (v2 + baked-in secilc fix for the fastboot drop) ===
# ROOT CAUSE of the v1 fastboot drop (found 2026-10-22 by offline dissection
# of the v1 system image; proven with a 2x2 control/test matrix):
# second-stage init compiles the split SELinux policy at every boot by
# running /system/bin/secilc over the system CIL set + the STOCK vendor's
# API-28 plat_pub_versioned.cil + vendor_sepolicy.cil. The stock plat_pub
# (line 4089) uses the legacy permission process:sigcont. The secilc built
# from the current LineageOS-Revived base FAILS to resolve it ("Failed to
# resolve permission sigcont"), LoadSplitPolicy returns false, init treats
# policy-load failure as fatal and reboots to the bootloader: Realme logo,
# then fastboot, no boot animation. The 2022 ROM's secilc compiles the same
# inputs cleanly. secilc is STATICALLY linked (NEEDED: libc/libm/libdl only),
# so the binary alone is the culprit; libsepol.so is swapped alongside it
# because the pair is the combination proven on-device (2026-10-22: v1 +
# pair boots). Both bases pin external/selinux to AOSP r46, so this is NOT
# fixable by a manifest revision pin — the deterministic fix is to bake the
# known-good pair into the target files before signing (below).
# The pair is fetched from the user's own repo
# (github.com/raisaputra94-ai/build_script @ main: secilc_2022,
# libsepol_2022.so — extracted from the working 2022 ROM's system) and
# md5-verified before and after the swap. Fail fast on any mismatch.
# AFTER the build: do NOT flash until the offline compile gate passes —
# send the signed zip for bench verification (exact-argv secilc run of the
# new build's CIL set against the stock vendor files must exit 0).
#
# === v2: RMX1805-org tree (v1 + corrected flash model) ===
# v2 changes NOTHING in the build itself; it corrects the flash plan only.
# 2026-10-21 finding (verified against the repo via GitHub API): the org
# vendor repo (RMX1805/vendor_oppo @ lineage-18.1, 180 files) has NO camera
# stack at all — no camera.msm8953.so, no provider impl, no libmmcamera_*,
# none of the 8 OPPO libs; only lib-imscamera.so (IMS telephony, unrelated).
# Flashing the org-built vendor.img would leave the device with NO camera
# provider whatsoever. The 2022 zip was system+boot ONLY and ran on the
# stock vendor partition — the faithful v2 flash reproduces exactly that:
# flash ONLY boot.img + system.img from the signed zip, leave the stock
# vendor untouched. (dtbo is a don't-care: the org prebuilt dtbo.img is
# byte-identical to stock's, md5 33e589c67993c2fc21f893a55ce59315.)
#
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
# Flash model (CORRECTED 2026-10-21): flash ONLY boot.img + system.img from
# the signed zip; LEAVE THE STOCK VENDOR PARTITION UNTOUCHED.
# Do NOT flash the full signed zip — the org-built vendor.img has NO camera
# stack at all (no camera.msm8953.so, no provider, no libmmcamera_*), and
# flashing it would leave the device with no camera provider whatsoever.
# This reproduces the proven 2022 architecture: the 2022 zip was
# system+boot only and ran on the stock A.71 vendor.
# In TWRP: Install > Install Image > flash boot.img to Boot,
# then system.img to System Image (not the zip install). Factory reset,
# then reboot. Run v0-bootimg-check.py against the signed zip first:
# PASS means flash per this plan, anything else comes back for review.
# dtbo: the org prebuilt is byte-identical to stock's — either way works.

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

# SOURCE FIX (v6: canonical patch): apply topjohnwu's revert of upstream
# dc4e541 to libsepol's CIL permission resolver, so the boot-time SELinux
# policy compile tolerates legacy permissions referenced by the stock
# vendor's API-28 plat_pub_versioned.cil (process:sigcont) instead of
# failing and dropping the phone to fastboot. In __cil_resolve_perms
# (libsepol/cil/src/cil_resolve_ast.c), an unresolvable permission is
# fatal only for map classes; otherwise it logs a warning and an empty
# list stands in for the unknown perm — the exact behavior identified in
# the 2022 ROM's resolver (see the v6 header note). The complete commit,
# including its attribution and message, is embedded verbatim below.
# Applied with git apply inside the synced external/selinux checkout;
# fail fast if the patch does not apply or the marker is missing.
SELINUX_PATCH="$PWD/.selinux_unknown_perm_revert.patch"
cat > "$SELINUX_PATCH" <<'PATCHEOF'
From 969114cff6ee973f47a3c84cacdef77e504d7bd9 Mon Sep 17 00:00:00 2001
From: topjohnwu <topjohnwu@gmail.com>
Date: Fri, 4 Sep 2020 19:02:11 -0700
Subject: [PATCH] Revert "libsepol: Make an unknown permission an error in CIL"

There are still invalid CILs out in the wild on Android.
Do not throw an error in this case, preserve the old behavior.

This reverts commit dc4e54126bf25dea4d51820922ccd1959be68fbc.
---
 libsepol/cil/src/cil_resolve_ast.c | 12 ++++++++----
 1 file changed, 8 insertions(+), 4 deletions(-)

diff --git a/libsepol/cil/src/cil_resolve_ast.c b/libsepol/cil/src/cil_resolve_ast.c
index daf873be0d..d1d220f8ec 100644
--- a/libsepol/cil/src/cil_resolve_ast.c
+++ b/libsepol/cil/src/cil_resolve_ast.c
@@ -131,14 +131,18 @@ static int __cil_resolve_perms(symtab_t *class_symtab, symtab_t *common_symtab,
 				}
 			}
 			if (rc != SEPOL_OK) {
+				struct cil_list *empty_list;
 				if (class_flavor == CIL_MAP_CLASS) {
 					cil_log(CIL_ERR, "Failed to resolve permission %s for map class\n", (char*)curr->data);
-				} else {
-					cil_log(CIL_ERR, "Failed to resolve permission %s\n", (char*)curr->data);
+					goto exit;
 				}
-				goto exit;
+				cil_log(CIL_WARN, "Failed to resolve permission %s\n", (char*)curr->data);
+				/* Use an empty list to represent unknown perm */
+				cil_list_init(&empty_list, perm_strs->flavor);
+				cil_list_append(*perm_datums, CIL_LIST, empty_list);
+			} else {
+				cil_list_append(*perm_datums, CIL_DATUM, perm_datum);
 			}
-			cil_list_append(*perm_datums, CIL_DATUM, perm_datum);
 		} else {
 			cil_list_append(*perm_datums, curr->flavor, curr->data);
 		}
PATCHEOF
if grep -q "Use an empty list to represent unknown perm" external/selinux/libsepol/cil/src/cil_resolve_ast.c; then
  echo "selinux resolver patch already applied (workspace reuse)."
else
  ( cd external/selinux && git apply "$SELINUX_PATCH" ) || {
    echo "ERROR: selinux resolver patch failed to apply to external/selinux" >&2; exit 1; }
fi
if ! grep -q "Use an empty list to represent unknown perm" external/selinux/libsepol/cil/src/cil_resolve_ast.c; then
  echo "ERROR: selinux resolver patch marker missing after apply" >&2
  exit 1
fi
echo "selinux resolver drop-unresolved-perms patch applied."

# DISPLAY DENSITY (v10): the build's own knob. BoardConfig.mk already
# sets TARGET_SCREEN_DENSITY := 384, which the build turns into
# ro.sf.lcd_density (and uses for the aapt preferred config). Point it
# at 360 (user preference; on this 720-wide panel = a 320dp-wide
# layout). This REPLACES the v8/v9 system.prop append: setting the
# property in both places would duplicate it in build.prop with the
# winner decided by file order. Idempotent; fail fast if not set.
BOARDCONFIG=device/oppo/RMX1805/BoardConfig.mk
if grep -q '^TARGET_SCREEN_DENSITY := ' "$BOARDCONFIG"; then
  sed -i 's|^TARGET_SCREEN_DENSITY := .*|TARGET_SCREEN_DENSITY := 360|' "$BOARDCONFIG"
else
  echo 'TARGET_SCREEN_DENSITY := 360' >> "$BOARDCONFIG"
fi
if ! grep -q '^TARGET_SCREEN_DENSITY := 360$' "$BOARDCONFIG"; then
  echo "ERROR: TARGET_SCREEN_DENSITY not 360 in $BOARDCONFIG after patch" >&2
  exit 1
fi
echo "display density set: TARGET_SCREEN_DENSITY := 360."

# DEVICE INIT (v9): replace init/init_msm8953.cpp with the corrected
# version embedded below. Two changes vs the org tree: (1) the Pixel 4 XL
# ("coral") fingerprint/description spoof in vendor_load_properties() is
# REMOVED — the build keeps its own original build fingerprint;
# (2) check_device() gains the missing 3072 heap tier (values = AOSP's
# 4096 profile) so the 3GB variant no longer falls through to the 2048
# profile. Every other heap value was verified byte-identical to AOSP
# android-11.0.0_r46's dalvik-heap profiles. Fail fast if the written
# file does not carry both changes.
INIT_CPP=device/oppo/RMX1805/init/init_msm8953.cpp
cat > "$INIT_CPP" <<'CPPEOF'
/*
   Copyright (c) 2016, The CyanogenMod Project
   Copyright (c) 2019-2020, The LineageOS Project

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are
   met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above
      copyright notice, this list of conditions and the following
      disclaimer in the documentation and/or other materials provided
      with the distribution.
    * Neither the name of The Linux Foundation nor the names of its
      contributors may be used to endorse or promote products derived
      from this software without specific prior written permission.

   THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
   WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
   ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
   BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
   CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
   SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
   BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
   WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
   OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
   IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <cstdlib>
#include <fstream>
#include <string.h>
#include <sys/sysinfo.h>
#include <unistd.h>
#include <stdlib.h>
#include <android-base/properties.h>
#define _REALLY_INCLUDE_SYS__SYSTEM_PROPERTIES_H_
#include <sys/_system_properties.h>

#include "property_service.h"
#include "vendor_init.h"

using ::android::base::SetProperty;

char const *heapstartsize;
char const *heapgrowthlimit;
char const *heapsize;
char const *heapminfree;
char const *heapmaxfree;
char const *heaptargetutilization;

void check_device()
{
    struct sysinfo sys;

    sysinfo(&sys);

    if (sys.totalram > 5072ull * 1024 * 1024) {
        // from - phone-xhdpi-6144-dalvik-heap.mk
        heapstartsize = "16m";
        heapgrowthlimit = "256m";
        heapsize = "512m";
        heaptargetutilization = "0.5";
        heapminfree = "8m";
        heapmaxfree = "32m";
    } else if (sys.totalram > 3072ull * 1024 * 1024) {
        // from - phone-xxhdpi-4096-dalvik-heap.mk
        heapstartsize = "8m";
        heapgrowthlimit = "192m";
        heapsize = "512m";
        heaptargetutilization = "0.6";
        heapminfree = "8m";
        heapmaxfree = "16m";
    } else if (sys.totalram > 2048ull * 1024 * 1024) {
        // 3072 tier (added): AOSP ships no 3072 profile, so the 3GB
        // variant used to fall through to the 2048 profile below.
        // Values are the 4096 profile's: same app-visible caps
        // (growthlimit/heapsize), but the GC free-list behaviour a
        // 3GB device can afford (minfree 8m vs 512k, maxfree 16m vs
        // 8m, targetutilization 0.6 vs 0.75) — less GC churn.
        heapstartsize = "8m";
        heapgrowthlimit = "192m";
        heapsize = "512m";
        heaptargetutilization = "0.6";
        heapminfree = "8m";
        heapmaxfree = "16m";
    } else {
        // from - phone-xhdpi-2048-dalvik-heap.mk
        heapstartsize = "8m";
        heapgrowthlimit = "192m";
        heapsize = "512m";
        heaptargetutilization = "0.75";
        heapminfree = "512k";
        heapmaxfree = "8m";
    }
}

void property_override(char const prop[], char const value[], bool add = true)
{
    auto pi = (prop_info *) __system_property_find(prop);

    if (pi != nullptr) {
        __system_property_update(pi, value, strlen(value));
    } else if (add) {
        __system_property_add(prop, strlen(prop), value, strlen(value));
    }
}

void property_override_dual(char const system_prop[], char const vendor_prop[],
    char const value[])
{
    property_override(system_prop, value);
    property_override(vendor_prop, value);
}

void vendor_load_properties()
{
    // dalvik
    check_device();
    property_override("dalvik.vm.heapstartsize", heapstartsize);
    property_override("dalvik.vm.heapgrowthlimit", heapgrowthlimit);
    property_override("dalvik.vm.heapsize", heapsize);
    property_override("dalvik.vm.heaptargetutilization", heaptargetutilization);
    property_override("dalvik.vm.heapminfree", heapminfree);
    property_override("dalvik.vm.heapmaxfree", heapmaxfree);

    // No fingerprint/description override: the build keeps its own
    // original build fingerprint (the stock tree spoofed a Pixel 4 XL
    // "coral" fingerprint here; removed at the user's request).
}
CPPEOF
if grep -q "google/coral/coral" "$INIT_CPP"; then
  echo "ERROR: fingerprint spoof still present in $INIT_CPP" >&2
  exit 1
fi
grep -q "3072 tier" "$INIT_CPP" || {
  echo "ERROR: 3072 heap tier missing in $INIT_CPP" >&2; exit 1; }
echo "device init replaced: original fingerprint kept, 3072 heap tier added."

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
echo "Target files built: $TF_ZIP"

# ---------------------------------------------------------------------------
# v5 IN-BUILD SELINUX GATE (runs BEFORE signing; a failed gate produces NO
# signed zip). Replicates the discriminating core of init's boot-time
# policy compile with the HOST secilc — built from the same patched
# external/selinux source as the device secilc in this build — against
# THIS build's real plat policy from the target files, plus a probe CIL
# standing in the vendor slot of init's argv: it references
# process:sigcont, the legacy permission whose resolution failure dropped
# v1 to fastboot. Strict compiler: fails here with that exact error.
# Patched compiler: compiles, and only then does signing proceed.
# ---------------------------------------------------------------------------
HOST_SECILC="out/host/linux-x86/bin/secilc"
if [[ ! -x "$HOST_SECILC" ]]; then
  HOST_SECILC="$(find out/host -name secilc -type f 2>/dev/null | head -n1)"
fi
[[ -x "$HOST_SECILC" ]] || { echo "ERROR: host secilc not found under out/host — cannot run the SELinux gate" >&2; exit 1; }
echo "SELinux gate: using host secilc $HOST_SECILC"

GATE_DIR="$PWD/.selinux_gate"
rm -rf "$GATE_DIR"
mkdir -p "$GATE_DIR"
unzip -q -o "$TF_ZIP" "SYSTEM/etc/selinux/*" -d "$GATE_DIR"
SE_DIR="$GATE_DIR/SYSTEM/etc/selinux"
[[ -f "$SE_DIR/plat_sepolicy.cil" ]] || { echo "ERROR: gate input missing from target files: plat_sepolicy.cil" >&2; exit 1; }
cat > "$GATE_DIR/probe.cil" <<'PROBEEOF'
(type gate_probe_t)
(allow gate_probe_t gate_probe_t (process (fork sigcont)))
PROBEEOF
touch "$GATE_DIR/fc_null"
GATE_ARGS=("$SE_DIR/plat_sepolicy.cil" -m -M true -G -N -c 30)
[[ -f "$SE_DIR/system_ext_sepolicy.cil" ]] && GATE_ARGS+=("$SE_DIR/system_ext_sepolicy.cil")
GATE_ARGS+=("$GATE_DIR/probe.cil" -o "$GATE_DIR/policy.out" -f "$GATE_DIR/fc_null")
if ! "$HOST_SECILC" "${GATE_ARGS[@]}"; then
  echo "ERROR: SELINUX GATE FAILED — this build's compiler cannot resolve the" >&2
  echo "legacy process:sigcont permission. The unknown-permission revert" >&2
  echo "(topjohnwu 969114c) is missing or ineffective. NO signed zip was" >&2
echo "produced. DO NOT FLASH." >&2
  exit 1
fi
rm -rf "$GATE_DIR"
echo "SELINUX GATE PASSED: this build's compiler tolerates legacy permissions."

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
# build/make/tools, so realpath() resolves to the wrong tree and signapk.jar
# is not found there. The jar lives in the host out dir.
./build/tools/releasetools/sign_target_files_apks -o -p out/host/linux-x86 -d "$KEYS_DIR" "$TF_ZIP" "$SIGNED_TF"
./build/tools/releasetools/ota_from_target_files -p out/host/linux-x86 -k "$KEYS_DIR/releasekey" "$SIGNED_TF" "$SIGNED_OTA"

echo "Signed ROM ready: $SIGNED_OTA"
echo "This build PASSED the in-build SELinux gate (see above) — the compiler"
echo "fix is verified inside this ROM. Flash directly, no external check needed."
echo "Flash plan (system+boot ONLY, stock vendor stays untouched):"
echo "  1. Unzip boot.img and system.img from $SIGNED_OTA."
echo "  2. TWRP > Install > Install Image: flash boot.img to Boot, then system.img to System Image."
echo "     Do NOT install the full zip and do NOT flash the built vendor.img"
echo "     (the org-built vendor has no camera stack - flashing it kills the camera)."
echo "  3. Coming from the v1 install (same ROM, same keys): no factory reset"
echo "     needed. Reboot. First-boot checks: WiFi/BT, IMEI, camera, backlight slider."
