#!/usr/bin/env bash
# Soft settings — set -u breaks envsetup/lunch on some AOSP trees
set +eu
export HOME=/serverhive/sal
export USE_CCACHE=1
export CCACHE_DIR=/serverhive/sal/.ccache
export CCACHE_EXEC=$(command -v ccache || true)
export ALLOW_MISSING_DEPENDENCIES=true
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export SKIP_ABI_CHECKS=true
export LLVM_PARALLEL_LINK_JOBS=4
export NINJA_STATUS='[%f/%t %p] '
JOBS="${BESTROM_JOBS:-16}"
TREE=/serverhive/sal/bestrom-a17
LOG=/serverhive/sal/logs/bestrom_guidix_build.log
HOSTBIN=$TREE/out/host/linux-x86/bin
export PATH="$HOSTBIN:$PATH"
cd "$TREE" || { echo "cd failed" | tee -a "$LOG"; exit 1; }
for t in fdtput fdtget fdtdump fdtoverlay dtc; do
  [ -x /usr/bin/$t ] && ln -sfn /usr/bin/$t $HOSTBIN/$t
done
[ -x $HOSTBIN/fdtoverlay ] && ln -sfn $HOSTBIN/fdtoverlay $HOSTBIN/fdtoverlaymerge
{
  echo "=== BestROM A17 bacon in tmux session bestrom ==="
  echo "HOST=$(hostname) JOBS=$JOBS START=$(date -u)"
} | tee "$LOG"
source build/envsetup.sh
echo "envsetup ok" | tee -a "$LOG"
lunch bestrom_peridot-trunk_staging-userdebug
echo "lunch ok TARGET_PRODUCT=$TARGET_PRODUCT" | tee -a "$LOG"
echo "=== BUILD START $(date -u) ===" | tee -a "$LOG"
m bacon -j$JOBS 2>&1 | tee -a "$LOG"
EC=${PIPESTATUS[0]}
echo "=== BUILD EXIT $EC $(date -u) ===" | tee -a "$LOG"
echo "BUILD_EXIT=$EC" > /serverhive/sal/logs/bestrom_guidix_exit.txt
exec bash
