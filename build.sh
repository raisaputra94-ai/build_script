#!/bin/bash
set -e

# Init
repo init -u https://github.com/LineageOS/android.git \
    -b lineage-18.1 \
    --depth=1 \
    --git-lfs \
    -g default,-mips,-darwin,-notdefault

# Clone manifest
rm -rf .repo/local_manifests
git clone -q https://github.com/raisaputra94-ai/local_manifests.git --depth 1 .repo/local_manifests

# Sync
for i in 1 2; do /opt/crave/resync.sh; done

# Build
source build/envsetup.sh
lunch lineage_RMX1805-user

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=rai
export TZ=Asia/Singapore

mka bacon
