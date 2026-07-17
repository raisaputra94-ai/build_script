#!/bin/bash
set -e
rm -rf .repo
export BUILD_HOSTNAME=android-build
export BUILD_USERNAME=rai
export TZ=Asia/Singapore

echo "start date = `date`"
# Init official LineageOS 18.1 (matches Project 85, so no issues)
repo init --depth 1 -u https://github.com/LineageOS/android -b lineage-18.1 --git-lfs

echo "clone manifest = `date`"
# Clone local manifest
rm -rf .repo/local_manifests
rm -f .repo/manifests/default.xml
git clone -q https://github.com/raisaputra94-ai/local_manifests.git --depth 1 .repo/local_manifests

echo "sync = `date`"
# Sync
/opt/crave/resync.sh

echo "lib = `date`"
#
FILE="/usr/lib/x86_64-linux-gnu/libncurses.so.5"
if [ ! -f "$FILE" ]; then
  echo "File '$FILE' does not exist."
  sudo ln -s /usr/lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.5 
  sudo ln -s /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5 
fi

echo "build = `date`"
# Build
source build/envsetup.sh
lunch lineage_RMX1805-user
mka bacon
