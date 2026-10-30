# === build-org-v22-lowram-audiofx-dpmd-batch5keepers: RMX1805-org tree (v21 + batch-5 keepers, PERMISSIVE stage-1) ===
# v22 = build-org-v21-lowram-audiofx-dpmd verbatim PLUS the v22 changes
# below, nothing else changed: low-RAM props, <=2048MiB heap tier,
# zram-by-default, AudioFX kept, RealmeParts kept, USB fix, density 360,
# secilc fix, signing and gate are exactly v21's.
# build-org-v21-lowram-audiofx-dpmd.sh itself is untouched
# (md5 6dc8021c96ffdb1d8708c8a908793425).
# QUEUE THIS FILE, NOT v21, if the batch-5 keepers below are wanted.
# User call 2026-10-30 ("do your best then") after the other-LLM
# stage1/stage2 review: apply the NARROWED version only, NOT stage1 as-is.
# Changes, both in enforcing_harvest.te only, allow count 28 -> 36 (+8):
#  (1) healthd charger_exec / charger_prop (charger-mode boot; from the
#      other LLM's batch-5 draft, tuples present in logs-2).
#  (2) init <-> hwservicemanager binder/dir/file/process rules (5 rules;
#      core service registration, tuples present in logs-2).
#  (3) permissioncontroller_app tethering_service find (1 rule).
# These 8 are plat-visible, so they compile in the plat build. They are
# STILL candidates, not functionally proven: v22 boots PERMISSIVE on
# purpose, so the setenforce 1 sweep on v22 itself is the proof step.
# NOT in v22, deliberately (held for that proof, or undeliverable):
#  - the whole odm_sepolicy.cil half: org BoardConfig defines NO odm
#    partition, flash model is boot+system only, stage1 adds no odm
#    image/flash step, and the file is self-described "not boot-tested,
#    not compiled against Android 11 plat". Count on nothing from it
#    until odm delivery is proven separately.
#  - neverallow-flagged rules: tee system_prop set (needs its own prop
#    type, not generic system_prop), system_app service_manager add
#    (UCE/default_android_service) -- compile only via
#    SELINUX_IGNORE_NEVERALLOWS and would block final hardening.
#  - hal_fingerprint_oppo (odm): this unit has NO fingerprint sensor.
#  - the rest of batch-5 plat items (init netlink_socket/rawip_socket,
#    capability2 wake_alarm, vendor_file/toolbox, socket_device unlink,
#    hal_camera default/radio/sysfs_net/vendor_shell, hal_wifi dir
#    search, hal_audio sysfs dir, kernel mnt_vendor, audioserver
#    vendor_default_prop, vendor_init set): candidates only, held for
#    the setenforce 1 functional delta, NOT rejected permanently.
# STAGING (this is the point of v22): the enforcing flip is HELD OUT.
# v22 KEEPS the permissive cmdline line (v21 deleted it). Test plan on
# v22: boot permissive, run the setenforce 1 sweep (WiFi/camera/BT,
# plus calls/SMS/data after top-up), capture the denial dump BEFORE
# reverting. Only if that sweep is clean does a later version remove
# the permissive line. Do NOT hand-edit v22's lunch to user: the script
# lunches userdebug on purpose, because a user build blocks adb root
# and therefore the whole setenforce/dmesg diagnostic plan (build
# 308136 was v21 + a user lunch edit by the user, not v21 as delivered).
# Bench gate before flashing still applies exactly as in v19/v21.
# pyyaml gate (separate, NOT fixed here): build 308136 died at soong
# bootstrap on vendor/apn "make-apns" -> undefined module "pyyaml".
# That failure is variant-independent and is NOT fixed by v22's policy
# changes. Do NOT queue v22 until the pyyaml tree check is done, or
# it dies in ~40s the same way.
#
# === build-org-v21-lowram-audiofx-dpmd: RMX1805-org tree (v19 + dpmd fix) ===
# v21 = build-org-v19-lowram-audiofx verbatim PLUS the dpmd fix below, nothing
# else changed: low-RAM props, <=2048MiB heap tier, zram-by-default, AudioFX
# kept, RealmeParts kept, USB fix, density 360, secilc fix, signing and gate
# are exactly v19's. build-org-v19-lowram-audiofx.sh itself is untouched.
# QUEUE THIS FILE, NOT v19, if the dpmd fix is wanted. NOTE: v20 is the
# withdrawn noparts file, so this is v21 to avoid a filename collision.
# User call 2026-10-29 ("just fix it already"): add the dpmd socket rules
# WITHOUT waiting for a mobile-data functional test (no SIM credit, so the
# data test is blocked until top-up). This is added by user call, NOT by
# harvest functional proof -- the data test after top-up is still recommended
# as validation, but it is not a queue blocker per that call.
# Changes, both in enforcing_harvest.te only, allow count 27 -> 28:
#  (1) allow init self:netlink_route_socket { read } ->
#      { bind create nlmsg_read read write } (comm dpmd at boot, logs-2).
#  (2) NEW allow init socket_device:sock_file { create setattr };
#      (init creating the dpmd socket file at boot, name=dpmd).
# NOT added: init diag_device:chr_file { ioctl write } for /dev/diag
# (comm dpmd) -- diag_device is vendor-only (declared in stock vendor
# diag.te, absent from plat_sepolicy.cil and plat_pub_versioned.cil), so it
# cannot be expressed plat-side, same parked class as ipacm-diag and
# netutils_wrapper diag. It stays parked; see the parked list below.
# NOT added: init netlink_socket / rawip_socket -- comm not verified as
# dpmd, left out rather than expanding init further on unverified data.
# Bench gate before flashing still applies exactly as in v19.
#
# === build-org-v19-lowram-audiofx: RMX1805-org tree (v18-lowram + AudioFX kept) ===
# v19-lowram-audiofx = build-org-v18-lowram verbatim PLUS ONE marked
# post-sync section (">>> V19 AUDIOFX SECTION >>>", inserted after the
# V17 LOW-RAM SECTION, before the SELINUX section) and one extra
# first-boot check line in the final echo. Nothing else changed:
# low-RAM props, <=2048MiB heap tier, zram-by-default, enforcing 27
# rules, USB fix, density 360, secilc fix, signing and gate are
# exactly v18-lowram's. build-org-v18-lowram.sh itself is untouched.
# QUEUE THIS FILE, NOT v18-lowram, if AudioFX is wanted.
# User call 2026-10-28: exclude AudioFX from removed_packages.
# The org tree ships device/oppo/RMX1805/remove_packages/Android.mk
# with LOCAL_OVERRIDES_PACKAGES := AudioFX, and device.mk includes
# the RemovePackages module, so AudioFX is NOT installed in v14-v18
# builds. This section removes AudioFX from that override list only.
# It does NOT add AudioFX to PRODUCT_PACKAGES: if the Lineage base
# does not include AudioFX on its own, this change alone will not
# install it, and the first-boot check below will tell. Do not bundle
# an explicit AudioFX package add into this version without that
# evidence, because the mandate here is exactly "exclude from
# removed_packages".
#
# === build-org-v18-lowram: RMX1805-org tree (v17-lowram + set_zram starts by default) ===
# v18-lowram = build-org-v17-lowram verbatim PLUS a change inside the
# V17 LOW-RAM SECTION's zram block only, plus this header. Nothing else
# changed: low-RAM props, <=2048MiB heap tier, enforcing 27 rules, USB
# fix, density, secilc fix, signing and gate are exactly v17-lowram's.
# build-org-v17-lowram.sh itself is untouched. QUEUE THIS FILE, NOT
# v17-lowram, if the low-RAM build is wanted.
# User call 2026-10-28 (after v17-lowram): "start it by default". That
# means the set_zram service must start with its class, not only on the
# boot_completed trigger. The org tree ships it as:
#   service set_zram /vendor/bin/sh /system/etc/init/set_zram.sh
#       class late_start
#       disabled
#       user root / group system / oneshot
#   on property:sys.boot_completed=1
#       start set_zram
# "disabled" overrides class-based starting, so the service only ran on
# boot_completed -- after the framework is up. Removing "disabled" from
# the set_zram block ONLY (ktweak keeps its disabled) makes init start
# it with the late_start class, which runs after /data is decrypted and
# the main services are up, but before boot_completed. The boot_completed
# "start set_zram" line is KEPT as a second run: the script is designed
# to be re-run (swapoff + reset first), so a late_start run that hit a
# not-yet-ready zram node is corrected at boot_completed, and a
# successful late_start run is simply re-initialised while almost
# nothing is swapped yet. Fail-fast: exactly one "disabled" removed,
# from set_zram only; ktweak still disabled; service definition, class,
# boot_completed trigger, Android.mk install rule and script contents
# all still verified.
#
# === build-org-v17-lowram: RMX1805-org tree (v16 + low-RAM optimisation, NO Go) ===
# v17-lowram = build-org-v16 verbatim PLUS ONE marked post-sync section
# (">>> V17 LOW-RAM SECTION >>>", inserted after DEVICE INIT, before the
# SELINUX section) and one extra first-boot check line in the final echo.
# Nothing else changed: enforcing 27 rules, USB fix, density 360, secilc
# source fix, signing and gate are exactly v16's. build-org-v16.sh itself
# is untouched. QUEUE THIS FILE, NOT v16, if the low-RAM build is wanted;
# v16 remains the non-low-RAM enforcing candidate.
# User call 2026-10-28: optimise for a low-RAM device, explicitly WITHOUT
# Go packages or a Go launcher. So this does NOT inherit go_defaults and
# adds NO Go packages, NO Launcher3QuickStepGo, NO GMS Go set, NO flattened
# APEX. What it does, in the new section:
#  (1) system.prop (via TARGET_SYSTEM_PROP, the proven density mechanism):
#      ro.config.low_ram=true (the framework low-RAM switch),
#      persist.sys.purgeable_assets=1, and all four dex2oat thread counts
#      the org tree sets to 8 -> 4 (ro.sys.fw.dex2oat_thread_count,
#      boot-dex2oat-threads, dex2oat-threads, image-dex2oat-threads).
#      Existing keys are replaced in place, never appended as duplicates
#      (a duplicate in build.prop would not reliably win).
#  (2) Dalvik heap for the <=2048MiB tier ONLY, in init_msm8953.cpp as
#      written by the DEVICE INIT section: heapgrowthlimit 192m -> 128m,
#      heapsize 512m -> 256m (the Go heap caps, taken without the Go
#      packages). The 3072/4096/6144 tiers are asserted unchanged. Heap
#      is set by init at boot and overrides build.prop, so editing
#      system.prop alone would NOT have done this; the org system.prop's
#      dalvik.vm.heapsize=36m line is likewise overridden by init.
#      On a 3GB unit this tier never triggers, but ro.config.low_ram
#      still applies system-wide -- this build is aimed at the 2GB unit.
#  (3) ZRAM: the org tree ALREADY defines the service the user asked to
#      enable, in rootdir/etc/init.qcom.rc:
#        service set_zram /vendor/bin/sh /system/etc/init/set_zram.sh
#      with class late_start, and "start set_zram" on
#      property:sys.boot_completed=1. The "disabled" keyword in the
#      service block does NOT mean off -- it means "do not start with
#      the class, start only on that explicit trigger", the same pattern
#      as the ktweak service right below it. The new section therefore
#      does NOT remove "disabled" (that would change zram start timing
#      for no tested reason); instead it FAILS THE BUILD if the service
#      definition, its boot_completed trigger, its Android.mk install
#      rule to /system/etc/init, or the script's lz4 / 50%-of-RAM
#      disksize / mkswap / swapon / swappiness=100 contents are missing.
#      That is the enable guarantee: a v17-lowram zip cannot ship with
#      zram silently absent.
# NOT in this ROM script (they live elsewhere, unchanged):
#  - kernel LMK table (aggressive 72/90/108/126/216/315 MB), KSM off,
#    kernel swappiness default: kernel workflow line, not this script.
#    The ROM still writes swappiness=100 at boot via set_zram.sh itself.
#  - No change to the permissive/enforcing state: v16's enforcing
#    cmdline removal and 27-rule harvest stand; bench gate before
#    flashing still applies exactly as in v16.
#
#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=RMX1805
export TZ=Asia/Singapore

# === v16: RMX1805-org tree (v15 review fixes: enforcing, NO qcom baseline, 27-rule harvest) ===
# v16 = v15 after a source-level review (2026-10-24) against lineage-18.1
# system/sepolicy, device/qcom/sepolicy and device/lineage/sepolicy. Three
# findings, each of which would have failed the v15 build at the policy
# compile step (hours in), so v16 fixes them and adds an early fail-fast:
# (1) BASELINE WIRING REMOVED. In Android 11 BOARD_PLAT_*_SEPOLICY_DIR is
#     compiled into system_ext_sepolicy.cil, and PRODUCT_*_SEPOLICY_DIRS
#     into product_sepolicy.cil, each against AOSP plat public/private
#     only (no system/sepolicy/vendor, no BOARD_VENDOR dirs). The baseline's
#     generic/ scope references types declared ONLY under qva/ (which v15
#     excluded): vendor_dpmservice (generic/private/dataservice_app.te),
#     vendor_vps_service + vendor_perf_service (generic/product/private/
#     systemhelper_app.te) -> unknown type, checkpolicy error. Pulling qva
#     in instead would add unharvested domains (userdebug qti-testscripts,
#     vendor_dataservice_app seapp re-domaining) AFTER the denial harvest
#     was taken without any baseline, and the stock Android 9 vendor uses
#     none of the vendor_* names it defines. v1-v14 (all baseline-less)
#     booted, and the harvest was taken on that exact policy, so enforcing
#     ships that same configuration. The dangling device/qcom/sepolicy/
#     private|public lines stay as-is (nonexistent dirs, ignored).
# (2) HARVEST 30 -> 27 RULES. Same compile scope means a rule may only name
#     types visible to plat public/private + the org dirs:
#       qti_init_shell                  (declared only in sepolicy-legacy-um
#                                        legacy/vendor/common/init_shell.te)
#       sysfs_mmc_host                  (declared nowhere in the 18.1 trees)
#       hal_graphics_composer_default   (system/sepolicy/vendor/ only)
#     -> the 2 qti_init_shell rules and the 1 vold/sysfs_mmc_host rule are
#     PARKED (accept the denial); the 2 surfaceflinger rules now use the
#     public attribute hal_graphics_composer_server (same method as the
#     other HAL rules). Every other type in the 27 was machine-checked as
#     declared (type/attribute/prop-macro/hal_attribute expansion).
# (3) EARLY POLICY PRE-CHECK: right after lunch, build only plat_sepolicy.cil,
#     system_ext_sepolicy.cil, product_sepolicy.cil and sepolicy (minutes) so
#     an unknown type fails before the multi-hour build, not after.
# Everything else is byte-identical to v15 (cmdline permissive flag removed,
# SELINUX_IGNORE_NEVERALLOWS := true kept, density, USB fix, gate, signing).
# BENCH GATE STILL REQUIRED before flashing: the in-build gate proves the
# compiler tolerates process:sigcont but does NOT compile against the STOCK
# vendor CIL; run the exact-argv secilc bench compile on the signed zip.
#
# === v15: RMX1805-org tree (v14 + QCOM baseline wiring + ENFORCING) ===
# v15 is the enforcing build, cut 2026-10-24 at the user's call. It
# adds THREE post-sync steps to v14 (one marked section, inserted
# after the device-init replacement); everything else is
# byte-identical to v14 (SELinux compiler patch + in-build gate,
# density 360, device init, USB Preferences fix):
# (1) QCOM SEPOLICY BASELINE WIRING: the org BoardConfig points
#     BOARD_PLAT_*_SEPOLICY_DIR at device/qcom/sepolicy/private and
#     device/qcom/sepolicy/public -- paths that do not exist in the
#     lineage-18.1 android_device_qcom_sepolicy repo (restructured
#     into generic/, qva/, legacy/), so v1-v14 all compiled the
#     platform policy with NO Qualcomm baseline. Rewire to the
#     baseline's own SEPolicy.mk plat/product lines, generic scope
#     only: qva is for QVA chipsets (not msm8953); legacy/vendor and
#     the legacy-um include stay out (vendor-side duplicates of the
#     stock vendor policy's types). Same change as
#     device_tree_selinux_qcom_baseline.patch.
# (2) HARVEST POLICY: installs sepolicy/private/enforcing_harvest.te
#     (batches 1-4 of the on-device permissive denial harvest,
#     exactly 27 allow statements, fail-fast counted), system-side
#     only -- the stock vendor policy is never touched.
# (3) ENFORCING MODE: deletes the cmdline line
#     'BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive'.
#     SELINUX_IGNORE_NEVERALLOWS stays := true on purpose (first
#     enforcing attempt; removing it is the later hardening pass).
# STATE AT CUT TIME: the batch-5 freeze round (voice calls in/out,
# SMS send/receive, one normal-reboot denial dump, bundled WiFi
# tombstone pull) has NOT been run yet. Telephony showed zero
# denials across batches 1-4, and every parked item was verified
# 2026-10-24 against the extracted stock policy set: stock ships
# enforcing and denies them all too. If batch 5 surfaces new rules
# they land in a v16; v15's policy is batches 1-4 + baselines.
# FLASH MODEL (unchanged): boot.img + system.img ONLY, stock vendor
# untouched, no factory reset. Keep the v14 (permissive) boot.img
# aside before flashing -- it is the TWRP escape hatch.
#
# === v14: RMX1805-org tree (v13 + "USB controlled by" section hidden) ===
# v14 = v13 with ONE extension to the same Settings patch, at the
# user's request (2026-10-23): the permanently-greyed "USB controlled
# by" section of the USB Preferences page is now HIDDEN entirely on
# this device. Mechanism: Settings hides a section when its
# controller's isAvailable() returns false;
# UsbDetailsDataRoleController.isAvailable() is
# '!UsbBackend.isSingleDataRoleSupported()', and that backend method
# (whose only caller is that check) now returns true when there is no
# USB port at all — a port-less gadget is a fixed-role device, so
# there is no role switcher to show. The embedded patch is now
# settings_usb_preferences_fix.patch (2 file diffs:
# UsbDetailsFunctionsController + UsbBackend) and the block below
# fail-fast greps BOTH markers. Everything else is byte-identical to
# v13: still PERMISSIVE, no harvest policy — the enforcing build is
# renumbered to v15 (= this file + build-org-v12.sh's two SELinux
# blocks, when the harvest freezes). v14 supersedes v13 as the
# queue candidate.
#
# === v13: RMX1805-org tree (v11 + USB Preferences fix ONLY) ===
# The user's call, 2026-10-23: ship the USB fix now; the ENFORCING
# changes drafted in build-org-v12.sh are deliberately NOT in this
# build because the SELinux denial harvest is not complete yet (the
# calls / SMS / normal-reboot gates are still open). SELinux stays
# PERMISSIVE here, exactly as in v10/v11 — the org cmdline flag is
# untouched and no harvest policy is installed.
#
# v13 = v11 + ONE post-sync step: the Settings patch
# (settings_usb_functions_norole.patch, embedded in the block below)
# is applied to packages/apps/Settings with a fail-fast marker grep.
# Root cause, proven 2026-10-23: the Android 10+ USB Preferences page
# disables its "Use USB for" list unless the USB port reports
# data-role DEVICE; this device has no android.hardware.usb HAL
# anywhere (stock vendor carries none, the org tree ships none) and
# the stock kernel's /sys/class/dual_role_usb/ is empty (both
# verified on-device), so the list was greyed out forever — while
# Developer Options > Default USB Configuration, a role-free path,
# worked. The patch treats DATA_ROLE_NONE as DEVICE in that one
# check. The identical block already exists in v12; it is reused
# verbatim (renumbered) so both scripts behave the same.
#
# v13 also supersedes the unqueued v11: the density fix
# (ro.sf.lcd_density=360 via system.prop) is included, so queueing
# v13 gains density + USB in one build. When the harvest freezes,
# the enforcing build returns as v14 = this file + v12's two
# SELinux blocks (harvest policy install + cmdline permissive
# removal), which are already written and sandbox-tested in
# build-org-v12.sh. Everything else is byte-identical to v11.
#
# === v11: RMX1805-org tree (v10 + density fix: system.prop restored) ===
# Build 306865 (v10) flashed and booted fine on 2026-10-23 — the
# source-fixed SELinux compiler is confirmed on-device — but the
# screen density was NOT 360. Root cause (proven from the pristine
# v1 system.img, not the extracted tree): /system/build.prop in the
# v1 build contains NO ro.sf.lcd_density at all, while the 2022 ROM's
# build.prop has ro.sf.lcd_density=360. So in this build system
# TARGET_SCREEN_DENSITY only drives the AAPT preferred config; it
# never writes the property. The v10 move away from the system.prop
# mechanism rested on that wrong premise. v11 restores the v8/v9
# system.prop block verbatim (ro.sf.lcd_density=360 via
# TARGET_SYSTEM_PROP — that file demonstrably lands in build.prop:
# rild.libpath from the same file is build.prop line 68 in v1) and
# KEEPS the BoardConfig sed (harmless; keeps the AAPT config at 360).
# Everything else is byte-identical to v10. NOTE: the enforcing
# build previously referred to as "v11" is renumbered to v12.
#
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

# DISPLAY DENSITY (v10, comment corrected in v11): BoardConfig.mk
# sets TARGET_SCREEN_DENSITY := 384. In this build system that knob
# drives the AAPT preferred config ONLY — it does not emit
# ro.sf.lcd_density (proven from the v1 system.img: the property is
# absent from build.prop entirely). The sed stays in v11 (harmless,
# keeps the asset bucket at 360); the property itself is set by the
# system.prop block right below. Idempotent; fail fast if not set.
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

# DISPLAY DENSITY (v11 fix, restoring the v8/v9 mechanism): bake
# ro.sf.lcd_density=360 into the org device tree's system.prop so the
# choice survives factory resets (the 'wm density 360' override does
# not). The org tree wires its system.prop via TARGET_SYSTEM_PROP
# (BoardConfig.mk) and sets no lcd_density of its own. On this 720-wide
# panel, density 360 gives a 320dp-wide layout. Idempotent: replace an
# existing value, append when absent, then verify.
SYSPROP=device/oppo/RMX1805/system.prop
if grep -q '^ro.sf.lcd_density=' "$SYSPROP"; then
  sed -i 's|^ro.sf.lcd_density=.*|ro.sf.lcd_density=360|' "$SYSPROP"
else
  echo 'ro.sf.lcd_density=360' >> "$SYSPROP"
fi
if ! grep -q '^ro.sf.lcd_density=360$' "$SYSPROP"; then
  echo "ERROR: ro.sf.lcd_density=360 missing in $SYSPROP after patch" >&2
  exit 1
fi
echo "display density baked: ro.sf.lcd_density=360."

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

# >>> V17 LOW-RAM SECTION >>>
# Low-RAM optimisation, NO Go packages/launcher (see v17-lowram header).
# The system.prop part is idempotent (existing keys replaced in place,
# absent keys appended, then every key verified). The heap edit is NOT
# meant to be rerun on an already-edited cpp: it assumes the DEVICE INIT
# section just rewrote the cpp fresh (as it does on every run, trees are
# re-synced), so it asserts the original 192m/512m values before editing.
# The heap edit is Python, targeted at the <=2048MiB tier only, with
# counts that prove the other tiers were not touched.
for PROP in 'ro.config.low_ram=true' 'persist.sys.purgeable_assets=1' \
    'ro.sys.fw.dex2oat_thread_count=4' 'dalvik.vm.boot-dex2oat-threads=4' \
    'dalvik.vm.dex2oat-threads=4' 'dalvik.vm.image-dex2oat-threads=4'; do
  KEY="${PROP%%=*}"
  if grep -q "^${KEY}=" "$SYSPROP"; then
    sed -i "s|^${KEY}=.*|${PROP}|" "$SYSPROP"
  else
    echo "$PROP" >> "$SYSPROP"
  fi
  grep -q "^${PROP}$" "$SYSPROP" || {
    echo "ERROR: $PROP missing in $SYSPROP after low-RAM patch" >&2; exit 1; }
  [ "$(grep -c "^${KEY}=" "$SYSPROP")" = "1" ] || {
    echo "ERROR: duplicate $KEY in $SYSPROP after low-RAM patch" >&2; exit 1; }
done
echo "low-RAM props baked: low_ram=true, purgeable_assets=1, dex2oat threads 8->4."

python3 - "$INIT_CPP" <<'PYEOF'
import sys
path = sys.argv[1]
text = open(path).read()
marker = "// from - phone-xhdpi-2048-dalvik-heap.mk"
head, sep, tail = text.partition(marker)
assert sep, "2048 heap tier marker missing in init cpp"
assert tail.count('heapgrowthlimit = "192m"') == 1, "2048 tier growthlimit not exactly once"
assert tail.count('heapsize = "512m"') == 1, "2048 tier heapsize not exactly once"
tail = tail.replace('heapgrowthlimit = "192m"', 'heapgrowthlimit = "128m"')
tail = tail.replace('heapsize = "512m"', 'heapsize = "256m"')
# Other tiers must still carry their original caps.
assert head.count('heapgrowthlimit = "192m"') == 2, "4096/3072 tiers growthlimit changed"
assert head.count('heapsize = "512m"') == 3, "4096/3072/6144 tiers heapsize changed"
open(path, "w").write(head + sep + tail)
PYEOF
grep -q 'heapgrowthlimit = "128m"' "$INIT_CPP" || {
  echo "ERROR: 2048-tier heapgrowthlimit not 128m in $INIT_CPP" >&2; exit 1; }
grep -q 'heapsize = "256m"' "$INIT_CPP" || {
  echo "ERROR: 2048-tier heapsize not 256m in $INIT_CPP" >&2; exit 1; }
[ "$(grep -c 'heapgrowthlimit = "192m"' "$INIT_CPP")" = "2" ] || {
  echo "ERROR: heapgrowthlimit 192m count changed outside 2048 tier" >&2; exit 1; }
[ "$(grep -c 'heapsize = "512m"' "$INIT_CPP")" = "3" ] || {
  echo "ERROR: heapsize 512m count changed outside 2048 tier" >&2; exit 1; }
echo "low-RAM heap: <=2048MiB tier now 128m growth / 256m max; other tiers unchanged."

ZRAM_RC=device/oppo/RMX1805/rootdir/etc/init.qcom.rc
ZRAM_SH=device/oppo/RMX1805/rootdir/etc/set_zram.sh
ZRAM_MK=device/oppo/RMX1805/rootdir/Android.mk
# ZRAM STARTS BY DEFAULT (v18-lowram, user call 2026-10-28): remove
# "disabled" from the set_zram block ONLY, so init starts it with its
# late_start class. ktweak keeps its disabled. The boot_completed
# "start set_zram" line is kept as a re-run safety net (see v18 header).
python3 - "$ZRAM_RC" <<'PYEOF'
import sys
path = sys.argv[1]
lines = open(path).read().splitlines(keepends=True)
out = []
in_zram = False
removed = 0
for line in lines:
    if line.startswith("service set_zram "):
        in_zram = True
    elif line.startswith("service ") or line.startswith("on "):
        in_zram = False
    if in_zram and line.strip() == "disabled":
        removed += 1
        continue
    out.append(line)
assert removed == 1, f"expected exactly one disabled removed from set_zram, got {removed}"
text = "".join(out)
assert "service ktweak " in text
kt = text.split("service ktweak ", 1)[1].split("\n\n", 1)[0]
assert "disabled" in kt, "ktweak disabled was changed, must stay"
open(path, "w").write(text)
PYEOF
if grep -A6 '^service set_zram ' "$ZRAM_RC" | grep -q 'disabled'; then
  echo "ERROR: disabled still present in set_zram block in $ZRAM_RC" >&2; exit 1
fi
grep -q '^service set_zram /vendor/bin/sh /system/etc/init/set_zram.sh$' "$ZRAM_RC" || {
  echo "ERROR: set_zram service definition missing in $ZRAM_RC" >&2; exit 1; }
grep -q 'class late_start' "$ZRAM_RC" || {
  echo "ERROR: set_zram class late_start missing in $ZRAM_RC" >&2; exit 1; }
grep -q '^    start set_zram$' "$ZRAM_RC" || {
  echo "ERROR: set_zram boot_completed re-run missing in $ZRAM_RC" >&2; exit 1; }
grep -q 'LOCAL_MODULE       := set_zram.sh' "$ZRAM_MK" || {
  echo "ERROR: set_zram.sh install rule missing in $ZRAM_MK" >&2; exit 1; }
for Z in "comp_algorithm" "disksize" "mkswap" "swapon" "swappiness"; do
  grep -q "$Z" "$ZRAM_SH" || {
    echo "ERROR: set_zram.sh missing $Z" >&2; exit 1; }
done
grep -q "echo 'lz4'" "$ZRAM_SH" || {
  echo "ERROR: set_zram.sh not using lz4" >&2; exit 1; }
grep -q 'echo 100 > /proc/sys/vm/swappiness' "$ZRAM_SH" || {
  echo "ERROR: set_zram.sh not setting swappiness=100" >&2; exit 1; }
echo "zram starts by default: disabled removed from set_zram (late_start), boot_completed re-run kept."
# <<< V17 LOW-RAM SECTION <<<

# >>> V19 AUDIOFX SECTION >>>
# Keep AudioFX: remove it from the org tree's RemovePackages override
# list (user call 2026-10-28). The org tree's remove_packages/Android.mk
# is the ONLY place AudioFX is removed: device.mk includes RemovePackages,
# and that module's LOCAL_OVERRIDES_PACKAGES := AudioFX is what keeps
# AudioFX out of the build. This section deletes exactly that one line
# and leaves the RemovePackages module and its mechanism intact (so any
# future overrides in that file still apply). Fail fast if the line is
# not exactly as expected, so a moved/changed tree cannot silently
# ship with AudioFX still removed.
AUDIOFX_MK=device/oppo/RMX1805/remove_packages/Android.mk
[ -f "$AUDIOFX_MK" ] || {
  echo "ERROR: $AUDIOFX_MK not found (synced tree?)" >&2; exit 1; }
grep -q '^LOCAL_OVERRIDES_PACKAGES := AudioFX$' "$AUDIOFX_MK" || {
  echo "ERROR: AudioFX override line not exactly as expected in $AUDIOFX_MK" >&2; exit 1; }
sed -i '/^LOCAL_OVERRIDES_PACKAGES := AudioFX$/d' "$AUDIOFX_MK"
# Post-checks: AudioFX must be gone from this file, module intact.
if grep -q 'AudioFX' "$AUDIOFX_MK"; then
  echo "ERROR: AudioFX still present in $AUDIOFX_MK after edit" >&2; exit 1
fi
grep -q '^LOCAL_MODULE := RemovePackages$' "$AUDIOFX_MK" || {
  echo "ERROR: RemovePackages module definition lost in $AUDIOFX_MK" >&2; exit 1; }
grep -q 'RemovePackages' device/oppo/RMX1805/device.mk || {
  echo "ERROR: RemovePackages missing from device.mk (mechanism changed?)" >&2; exit 1; }
echo "AudioFX kept: removed from RemovePackages override list (module intact)."
# <<< V19 AUDIOFX SECTION <<<

# >>> V15 SELINUX SECTION >>>
# QCOM SEPOLICY BASELINE (v16): intentionally NOT wired (see v16 header,
# finding 1). BOARDCONFIG is still needed below for the cmdline edit.
BOARDCONFIG=device/oppo/RMX1805/BoardConfig.mk
for L in 'device/qcom/sepolicy/generic' 'device/qcom/sepolicy/qva' 'device/qcom/sepolicy-legacy-um'; do
  if grep -q "$L" "$BOARDCONFIG"; then
    echo "ERROR: unexpected qcom sepolicy wiring ($L) in $BOARDCONFIG" >&2; exit 1
  fi
done
echo "qcom sepolicy baseline: not wired (as harvested)."

# ENFORCING POLICY (v15): install the denial-harvest policy into the
# org device tree's plat-private sepolicy dir (BoardConfig.mk wires
# sepolicy/private via BOARD_PLAT_PRIVATE_SEPOLICY_DIR). Content is
# the consolidated batches 1-4 draft (27 allow statements after v16 review) verbatim, plus the v21 dpmd fix, plus
# the v22 batch-5 keepers (36 total), preceded by a shipped-as header.
# Fail fast if the written file does not carry exactly 36 allow statements.
HARVEST_TE=device/oppo/RMX1805/sepolicy/private/enforcing_harvest.te
cat > "$HARVEST_TE" <<'HARVESTHDR'
# RMX1805 enforcing harvest -- SHIPPED in build-org-v22 (2026-10-30).
# Batches 1-4 (27 allow statements after v16 review) + v21 dpmd fix
# + v22 batch-5 keepers (8 rules, plat-side only) = 36 total.
# Source: enforcing_batch1234_draft.te + other-LLM batch-5 draft
# (enforcing_batch1235.te), narrowed to the keepers listed in the
# v22 header. v22 boots PERMISSIVE; the setenforce 1 sweep on v22
# is the proof step for the 8 keepers.
HARVESTHDR
cat >> "$HARVEST_TE" <<'HARVESTEOF'
# RMX1805 org + stock vendor — SELinux enforcing draft (DRAFT)
# Batches 1+2+3+4 consolidated. Supersedes enforcing_batch123_draft.te.
# Sources: permissive denial harvests, 2026-10-22 — batch 1: fresh-flash
# boot + idle; batch 2: Settings browsing, Aperture, GMS; batch 3:
# extended session (Jelly browsing, MediaProvider scan, one WiFi HAL
# crash/restart); batch 4: WiFi hotspot on / client connected / off
# (no new rules, one new parked item — hal_wifi_hostapd, see below).
# Remaining unconfirmed surface: voice calls (in + out) and SMS
# (send + receive) — zero telephony denials across all batches, so
# clean-vs-untested is still open — plus one normal-reboot dump.
# Fingerprint is N/A: user confirmed this unit has no sensor.
# Coverage now: boot, idle, Settings, camera, GMS, browsing, hotspot.
# Target location: device/oppo/RMX1805/sepolicy/private/ (plat-private).
#
# Method note: rules may only reference types/attributes visible to the
# PLAT build. Vendor-only types (declared in the stock vendor_sepolicy.cil,
# absent from plat and from plat_pub_versioned.cil) are reached through
# their PUBLIC attribute memberships instead:
#   hal_light_default_exec -> vendor_file_type
#   hal_wifi_default       -> hal_wifi_server (attribute)
#   hal_camera_default     -> hal_camera_server (attribute)
#   hal_audio_default      -> hal_audio_server (attribute)
#   hal_memtrack_default   -> hal_memtrack_server (attribute)
#   silead_fpd_device      -> dev_type
# SELINUX_IGNORE_NEVERALLOWS is still := true in the org BoardConfig;
# rules flagged [neverallow?] need re-checking at final hardening.

# ================= batch 1: boot + idle =================

# --- init mount setup (first/second stage mount_all) ---
allow init vendor_file_type:file mounton;
allow init oemfs:dir mounton;

# --- fsck on the persist block device (e2fsck, mmcblk0p5) ---
allow fsck block_device:blk_file { read write open ioctl };

# --- toolbox (chattr) on /data/media during init scripts ---
allow toolbox rootfs:dir { read open };

# --- dpmd / netutils-wrapper chain (vendor service running in init domain) ---
allow init netutils_wrapper_exec:file { read open getattr execute execute_no_trans };
allow init system_file:file execute_no_trans; # [neverallow?] iptables via wrapper
allow init self:netlink_route_socket { bind create nlmsg_read read write }; # v21 dpmd expansion (was read only)
allow init socket_device:sock_file { create setattr }; # v21: init creating /dev/socket/dpmd at boot

# --- qti_init_shell boot scripts ---
# (v16) qti_init_shell rules PARKED: type is vendor-only, see parked list.

# --- system_server reading the RTC node ---
allow system_server sysfs:file { read open getattr };

# --- vold probing /mnt/vendor/persist ---
allow vold mnt_vendor_file:dir { read open ioctl };

# --- WiFi HAL reading its NV calibration from persist ---
allow hal_wifi_server mnt_vendor_file:file { read open };

# --- vold storage tuning (read_ahead_kb): v16 PARKED, sysfs_mmc_host not plat-visible ---

# --- dataservices app writing the dpmd socket ---
allow system_app socket_device:sock_file { write };

# ================= batch 2: light usage =================

# --- Settings reading memory statistics (zram + vmalloc) ---
allow system_app sysfs_zram:dir { search };
allow system_app sysfs_zram:file { read open getattr };
allow system_app proc_vmallocinfo:file { read open getattr };

# --- GMS reading adbd properties ---
allow gmscore_app system_adbd_prop:file { read open getattr };
allow gmscore_app adbd_prop:file { read open getattr };

# --- surfaceflinger inspecting the composer process (/proc/<pid>) ---
# v16: via public attribute (hal_graphics_composer_default is vendor-only)
allow surfaceflinger hal_graphics_composer_server:dir { search };
allow surfaceflinger hal_graphics_composer_server:file { read open getattr };

# --- camera HAL: debug props, system props, flash/torch LED path ---
allow hal_camera_server persist_debug_prop:file { read open getattr };
allow hal_camera_server system_prop:file { read open getattr };
allow hal_camera_server sysfs_leds:dir { search };

# --- audio HAL writing to an audioserver pipe ---
allow hal_audio_server audioserver:fifo_file { write };

# --- vendor_default_prop reads (property defaults bucket) ---
# Sources observed: system_app, untrusted_app, gmscore_app, isolated_app.
allow { system_app untrusted_app gmscore_app isolated_app } vendor_default_prop:file { read open getattr };

# ================= batch 3: extended session =================

# --- GMS calling the memtrack HAL ---
allow gmscore_app hal_memtrack_server:binder { call };

# --- MediaProvider scanning /data/cache/recovery ---
allow mediaprovider cache_recovery_file:dir { read open };

# --- crash_dump reading props while dumping a crashed HAL (batch 4 hotspot: same tuples recurred at both toggles, no change) ---
allow crash_dump exported_wifi_prop:file { open getattr };
allow crash_dump hwservicemanager_prop:file { open getattr };

# ================= batch 4: WiFi hotspot on / client / off =================
# No new rules. Every hotspot-window tuple was already drafted above
# (init -> netutils_wrapper_exec chain, init -> system_file
# execute_no_trans, init self netlink_route_socket, crash_dump props) or
# already parked below (hal_wifi -> vendor_tombstone_data_file, perms
# confirmed { search read open }). One NEW parked item from this batch:
# hal_wifi_hostapd (see parked list).
# Observation: the WiFi HAL crashed/restarted at BOTH hotspot toggles
# (on ~15:16:27, off ~15:17:25) — permissive, so NOT denial-caused; same
# pattern as the batch-3 idle crash at ~3345s. Monitor in the soak.

# ================= v22: batch-5 keepers (plat-side only) =================
# From the other-LLM batch-5 draft; tuples present in logs-2. These are
# candidates being TESTED on this permissive build, not proven rules:
# the setenforce 1 sweep on v22 decides whether they stay.
# --- charger mode (offmode charging; healthd runs /system/bin/charger) ---
allow healthd charger_exec:file { entrypoint execute getattr read open map };
allow healthd charger_prop:file { getattr open read };
# --- hwservicemanager <-> init (core service registration) ---
allow init hwservicemanager:binder { call };
allow hwservicemanager init:binder { transfer };
allow hwservicemanager init:dir { search };
allow hwservicemanager init:file { open read };
allow hwservicemanager init:process { getattr };
# --- permission controller finding the tethering service ---
allow permissioncontroller_app tethering_service:service_manager { find };

# PARKED (v16 additions first):
#   qti_init_shell -> dev_type:chr_file { getattr setattr }     (chown /dev/silead_fp; no sensor on
#                                                                this unit, harmless)
#   qti_init_shell -> vendor_file:file execute_no_trans         (/vendor/bin/awk from init scripts:
#                                                                SUSPECT if post-boot tuning/zram
#                                                                scripts misbehave under enforcing)
#   vold -> sysfs_mmc_host:file write                           (read_ahead_kb tuning; perf only)
# PARKED — cannot be expressed plat-side (vendor-only types with no
# usable public attribute); accept the denial, monitor impact:
#   ipacm-diag -> diag_device:chr_file { rw open ioctl }        (diagnostics only)
#   netutils_wrapper -> diag_device:chr_file { read write }     (diagnostics only)
#   vold -> oppo_reserve_file:dir { read open ioctl }           (vold probe; not vold-managed)
#   vendor_camera_prop reads by system_server, system_app,
#     gmscore_app, untrusted_app (Aperture, Jelly)               (MOST-HIT parked item: camera prop
#                                                                hints — suspect #1 if camera
#                                                                misbehaves under enforcing)
#   camera_prop reads by untrusted_app (Aperture)               (vendor-declared prop type)
#   hal_camera_default -> vendor_system_prop                    (vendor-declared prop type)
#   system_app -> hal_rcsservice:binder { call transfer }       (RCS features only)
#   init <-> hal_dpmQmiMgr:binder { call } (both directions)    (DPM QMI link; rest of the dpmd
#                                                                chain is drafted in batch 1)
#   init (comm dpmd) -> diag_device:chr_file { ioctl write }   (v21: /dev/diag, vendor-only type,
#                                                                cannot be expressed plat-side;
#                                                                same parked class as ipacm-diag diag)
#   hal_wifi_default -> vendor_tombstone_data_file:dir          (WiFi HAL tombstone bookkeeping;
#     { search read open }                                       vendor-declared type, only
#                                                                data_file_type — too broad)
#   hal_wifi_hostapd_default -> wifi_vendor_data_file:dir       (BATCH 4, hotspot: hostapd removing
#     { write remove_name }                                      the "hostapd" entry from
#                                                                /data/vendor/wifi. Type is vendor-
#                                                                only; attributes are file_type +
#                                                                data_file_type only — too broad.
#                                                                NOTE: the stock vendor policy
#                                                                itself grants hostapd only
#                                                                { read getattr search open } on
#                                                                this dir — the write/remove is
#                                                                ungranted even on stock.
#                                                                Label CHECKED on-device
#                                                                2026-10-22: /data/vendor/wifi/
#                                                                hostapd IS correctly labelled
#                                                                hostapd_data_file (mislabel
#                                                                theory refuted). Hostapd tries
#                                                                to remove its own top dir from
#                                                                the parent at each AP toggle —
#                                                                reads as best-effort cleanup;
#                                                                impact unknown until the
#                                                                enforcing test. Remains
#                                                                suspect #1 if HOTSPOT breaks
#                                                                under enforcing.)
#
# SKIPPED — noise / correct to block:
#   zygote -> adb_data_file:dir { search }                      (KernelSU manager spawn probing)
#   untrusted_app -> postinstall_mnt_dir:dir { getattr }        (KernelSU manager probing)
#   qti_init_shell -> self:fifo_file { ioctl }                  (pipe FIONREAD noise)
HARVESTEOF
ALLOW_COUNT=$(grep -c '^allow ' "$HARVEST_TE")
if [ "$ALLOW_COUNT" -ne 36 ]; then
  echo "ERROR: enforcing_harvest.te has $ALLOW_COUNT allow statements, expected 36" >&2
  exit 1
fi
echo "enforcing policy installed: $HARVEST_TE (36 allow statements, batches 1-4 minus 3 parked + v21 dpmd + v22 batch-5 keepers)."

# v22 STAGE-1: KEEP the permissive flag -- do NOT delete it (v21 deleted
# it). The org BoardConfig.mk adds it as its own line (BOARD_KERNEL_CMDLINE +=
# androidboot.selinux=permissive). v22 must boot PERMISSIVE so the
# setenforce 1 sweep can prove the 8 keepers without risking a boot
# loop from an untested policy. Fail fast if the permissive line is
# somehow already gone (that would mean this is not a stage-1 build).
# SELINUX_IGNORE_NEVERALLOWS must still be := true (kept deliberately
# for the first enforcing attempt; removing it is the later hardening step).
if ! grep -q '^BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive$' "$BOARDCONFIG"; then
  echo "ERROR: permissive cmdline line missing from $BOARDCONFIG -- v22 must boot permissive" >&2
  exit 1
fi
if ! grep -q '^SELINUX_IGNORE_NEVERALLOWS := true$' "$BOARDCONFIG"; then
  echo "ERROR: SELINUX_IGNORE_NEVERALLOWS is no longer := true in $BOARDCONFIG" >&2
  exit 1
fi
echo "boot mode: SELinux PERMISSIVE (v22 stage-1 test build; enforcing flip held out)."
# <<< V15 SELINUX SECTION <<<

# USB PREFERENCES FIX (v14): apply the embedded Settings patch so the
# "Use USB for" list is not permanently greyed out on this HAL-less
# device and the unusable "USB controlled by" section is hidden
# (see the v14/v13 header notes for the full root cause). Applied
# with git apply inside the synced packages/apps/Settings checkout;
# fail fast if the patch does not apply or either marker is missing.
USB_PATCH="$PWD/.settings_usb_preferences_fix.patch"
cat > "$USB_PATCH" <<'USBPATCHEOF'
diff --git a/src/com/android/settings/connecteddevice/usb/UsbBackend.java b/src/com/android/settings/connecteddevice/usb/UsbBackend.java
index a8018a1..7d9679a 100644
--- a/src/com/android/settings/connecteddevice/usb/UsbBackend.java
+++ b/src/com/android/settings/connecteddevice/usb/UsbBackend.java
@@ -163,7 +163,13 @@ public class UsbBackend {
     }
 
     public boolean isSingleDataRoleSupported() {
-        return mPort != null && mPortStatus != null
+        // Devices without a USB HAL have no port whose role could be
+        // switched; treat them as fixed-role so the "USB controlled by"
+        // section is hidden instead of shown permanently disabled.
+        if (mPort == null) {
+            return true;
+        }
+        return mPortStatus != null
                 && ((!mPortStatus
                 .isRoleCombinationSupported(POWER_ROLE_SINK, DATA_ROLE_HOST)
                 && !mPortStatus
diff --git a/src/com/android/settings/connecteddevice/usb/UsbDetailsFunctionsController.java b/src/com/android/settings/connecteddevice/usb/UsbDetailsFunctionsController.java
index 99e9d50..260956e 100644
--- a/src/com/android/settings/connecteddevice/usb/UsbDetailsFunctionsController.java
+++ b/src/com/android/settings/connecteddevice/usb/UsbDetailsFunctionsController.java
@@ -17,6 +17,7 @@
 package com.android.settings.connecteddevice.usb;
 
 import static android.hardware.usb.UsbPortStatus.DATA_ROLE_DEVICE;
+import static android.hardware.usb.UsbPortStatus.DATA_ROLE_NONE;
 import static android.net.ConnectivityManager.TETHERING_USB;
 
 import android.content.Context;
@@ -96,7 +97,10 @@ public class UsbDetailsFunctionsController extends UsbDetailsController
             Log.d(TAG, "refresh() connected : " + connected + ", functions : " + functions
                     + ", powerRole : " + powerRole + ", dataRole : " + dataRole);
         }
-        if (!connected || dataRole != DATA_ROLE_DEVICE) {
+        // Legacy gadgets without a USB HAL never report a port, so their data
+        // role is always DATA_ROLE_NONE even while connected as a device.
+        // Don't keep the function list disabled for them.
+        if (!connected || (dataRole != DATA_ROLE_DEVICE && dataRole != DATA_ROLE_NONE)) {
             mProfilesContainer.setEnabled(false);
         } else {
             // Functions are only available in device mode
USBPATCHEOF
USB_JAVA=packages/apps/Settings/src/com/android/settings/connecteddevice/usb/UsbDetailsFunctionsController.java
USB_BACKEND=packages/apps/Settings/src/com/android/settings/connecteddevice/usb/UsbBackend.java
if grep -q 'dataRole != DATA_ROLE_NONE' "$USB_JAVA" && grep -q 'no port whose role could be' "$USB_BACKEND"; then
  echo "Settings USB Preferences patch already applied (workspace reuse)."
else
  ( cd packages/apps/Settings && git apply "$USB_PATCH" ) || {
    echo "ERROR: Settings USB Preferences patch failed to apply" >&2; exit 1; }
fi
if ! grep -q 'dataRole != DATA_ROLE_NONE' "$USB_JAVA"; then
  echo "ERROR: Settings USB functions marker missing after apply" >&2
  exit 1
fi
if ! grep -q 'no port whose role could be' "$USB_BACKEND"; then
  echo "ERROR: Settings USB controlled-by-hide marker missing after apply" >&2
  exit 1
fi
echo "Settings USB Preferences patch applied (function list works; 'controlled by' hidden)."


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
# v16 EARLY POLICY PRE-CHECK: compile only the policy modules (minutes).
# An unknown type / bad macro in the harvest or wiring dies here, not after
# the multi-hour image build. 'sepolicy' is the monolithic all-policy build.
mka plat_sepolicy.cil system_ext_sepolicy.cil sepolicy || {
  echo "ERROR: early sepolicy pre-check failed - fix policy before a full build" >&2; exit 1; }
echo "early sepolicy pre-check passed."
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
echo "fix is verified inside this ROM. BEFORE FLASHING run the exact-argv secilc bench compile against the STOCK vendor CIL (v16 adds system_ext rules the gate cannot check against it)."
echo "Flash plan (system+boot ONLY, stock vendor stays untouched):"
echo "  1. Unzip boot.img and system.img from $SIGNED_OTA."
echo "  2. TWRP > Install > Install Image: flash boot.img to Boot, then system.img to System Image."
echo "     Do NOT install the full zip and do NOT flash the built vendor.img"
echo "     (the org-built vendor has no camera stack - flashing it kills the camera)."
echo "  3. Coming from the v1 install (same ROM, same keys): no factory reset"
echo "     needed. Reboot. First-boot checks: WiFi/BT, IMEI, camera, backlight slider,"
 echo "     display density 360, USB Preferences: list selectable, controlled-by hidden."
echo "     Low-RAM checks: getprop ro.config.low_ram (=true), cat /proc/swaps +"
 echo "     /sys/block/zram0/disksize (zram up, ~50% of RAM), dex2oat threads =4."
 echo "     AudioFX check (v19): AudioFX app should appear in the app drawer"
 echo "     (it was removed by RemovePackages in v14-v18). If it does not"
 echo "     appear, the Lineage base does not include it on its own and a"
 echo "     follow-up version must add it explicitly -- do not re-add the override." 
