#!/bin/bash

# Install missing ncurses5 libraries
wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb && \
    sudo dpkg -i libtinfo5_6.3-2_amd64.deb &>/dev/null && \
    rm -f libtinfo5_6.3-2_amd64.deb

wget -q https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libncurses5_6.3-2_amd64.deb && \
    sudo dpkg -i libncurses5_6.3-2_amd64.deb &>/dev/null && \
    rm -f libncurses5_6.3-2_amd64.deb

# Init LineageOS-Revived 17.1
repo init -u https://github.com/LineageOS-Revived/android.git \
    -b lineage-17.1 \
    --depth=1 \
    --git-lfs \
    -g default,-mips,-darwin,-notdefault

# Clone your manifest
rm -rf .repo/local_manifests
git clone -q https://github.com/raisaputra94-ai/rmx1805_manifest.git .repo/local_manifests

# Sync (run twice like bimuafaq does, for reliability)
for i in 1 2; do /opt/crave/resync.sh; done

# Build
source build/envsetup.sh
lunch lineage_RMX1805-user

export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=builder
export TZ=Asia/Singapore

mka bacon
