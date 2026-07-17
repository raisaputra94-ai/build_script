#!/bin/bash
set -e

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=rai
export TZ=Asia/Singapore

# Install libncurses5
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb && \
    sudo dpkg -i libtinfo5_6.3-2_amd64.deb && rm -f libtinfo5_6.3-2_amd64.deb || true
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb && \
    sudo dpkg -i libncurses5_6.3-2_amd64.deb && rm -f libncurses5_6.3-2_amd64.deb || true

# Fix: delete CORRUPTED manifests repo specifically
rm -rf .repo/manifests
rm -rf .repo/local_manifests

# Re-init (will re-clone manifests git repo fresh)
repo init -u https://github.com/LineageOS/android.git \
    -b lineage-18.1 \
    --depth=1 \
    --git-lfs

# Add local manifests
git clone -q https://github.com/raisaputra94-ai/local_manifests.git --depth 1 .repo/local_manifests

# Sync
/opt/crave/resync.sh

# Build
source build/envsetup.sh
lunch lineage_RMX1805-user
mka bacon
