#!/bin/bash
set -e

# Init official LineageOS 18.1 (matches Project 85, so no issues)
repo init -u https://github.com/LineageOS/android.git \
    -b lineage-18.1 \
    --depth=1

# Clone local manifest
rm -rf .repo/local_manifests
git clone -q https://github.com/raisaputra94-ai/local_manifests.git --depth 1 .repo/local_manifests

# Sync
/opt/crave/resync.sh

# Build
source build/envsetup.sh
lunch lineage_RMX1805-user

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=rai
export TZ=Asia/Singapore

mka bacon
