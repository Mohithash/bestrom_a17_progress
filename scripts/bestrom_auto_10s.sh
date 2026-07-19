#!/usr/bin/env bash
# BestROM auto-check every 10s: if failed/idle with error, fix known issues and restart.
# Policy: always fix without permission.
set +e
export HOME=/serverhive/sal
TREE=/serverhive/sal/bestrom-a17
LOG=/serverhive/sal/logs/bestrom_guidix_build.log
EXITF=/serverhive/sal/logs/bestrom_guidix_exit.txt
WATCHLOG=/serverhive/sal/logs/bestrom_auto_10s.log
LOCK=/tmp/bestrom_auto_10s.lock
INTERVAL=10

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another auto_10s running" >>"$WATCHLOG"
  exit 0
fi

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" | tee -a "$WATCHLOG"; }

is_building() {
  pgrep -u sal -f 'combined-bestrom_peridot' >/dev/null 2>&1 && return 0
  pgrep -u sal -f 'bestrom-a17/out/soong_ui' >/dev/null 2>&1 && return 0
  return 1
}

apply_known_fixes() {
  local did=0
  # Absolute HOSTCC / ARCH / clang
  if [ -f /serverhive/sal/bin/patch_hostcc.py ]; then
    python3 /serverhive/sal/bin/patch_hostcc.py >>"$WATCHLOG" 2>&1
    did=1
  fi
  # Bare HOSTCC=clang override
  sed -i '/KERNEL_MAKE_FLAGS += HOSTCC=clang HOSTCXX=clang++/d' \
    "$TREE/vendor/bestrom/build/tasks/kernel.mk" 2>/dev/null
  # pahole
  echo -e '#!/bin/sh\nexit 0' > "$TREE/kernel/xiaomi/sm8635/scripts/pahole-flags.sh"
  chmod +x "$TREE/kernel/xiaomi/sm8635/scripts/pahole-flags.sh"
  # voltage includes
  sed -i 's|^[[:space:]]*include.*voltage|# BestROM: &|' \
    "$TREE/device/xiaomi/peridot/BoardConfig.mk" 2>/dev/null
  sed -i 's|^[[:space:]]*-include.*voltage|# BestROM: &|' \
    "$TREE/device/xiaomi/peridot/BoardConfig.mk" 2>/dev/null
  # ensure sepolicy wrapper
  grep -q 'device/bestrom/sepolicy/qcom_sepolicy.mk' \
    "$TREE/device/xiaomi/peridot/BoardConfig.mk" 2>/dev/null || \
    sed -i 's|include device/qcom/sepolicy_vndr/SEPolicy.mk|include device/bestrom/sepolicy/qcom_sepolicy.mk|' \
      "$TREE/device/xiaomi/peridot/BoardConfig.mk" 2>/dev/null
  # ARCH force
  grep -q 'KERNEL_ARCH := arm64' "$TREE/device/xiaomi/peridot/BoardConfig.mk" || \
    echo 'KERNEL_ARCH := arm64' >> "$TREE/device/xiaomi/peridot/BoardConfig.mk"
  return $did
}

start_build() {
  for p in $(pgrep -u sal -f 'bestrom-a17/out/soong_ui' 2>/dev/null); do kill $p 2>/dev/null; done
  for p in $(pgrep -u sal -f 'combined-bestrom_peridot' 2>/dev/null); do kill $p 2>/dev/null; done
  sleep 2
  tmux kill-session -t bestrom 2>/dev/null
  sleep 1
  # keep out warm; only clear failed host scripts sometimes
  if grep -q 'fixdep\|clang: not found\|arch//' "$LOG" 2>/dev/null; then
    rm -rf "$TREE/out/target/product/peridot/obj/KERNEL_OBJ/scripts" 2>/dev/null
  fi
  : > "$LOG"
  # ensure inner exists
  if [ ! -x /serverhive/sal/bin/bestrom_byobu_inner.sh ]; then
    log "missing inner script — cannot start"
    return 1
  fi
  tmux new-session -d -s bestrom 'bash /serverhive/sal/bin/bestrom_byobu_inner.sh'
  log "started tmux bestrom"
}

log "=== auto-check every ${INTERVAL}s START ==="
log "load=$(cut -d' ' -f1-3 /proc/loadavg)"

# If not building and last exit failed or no success, start now
if ! is_building; then
  if ! grep -q 'BUILD EXIT 0' "$LOG" 2>/dev/null; then
    log "not building — apply fixes and start"
    apply_known_fixes
    start_build
  fi
fi

fail_streak=0
while true; do
  sleep "$INTERVAL"
  load=$(cut -d' ' -f1-3 /proc/loadavg)
  if is_building; then
    fail_streak=0
    prog=$(grep -oE '\[[0-9]+%[[:space:]]+[0-9]+/[0-9]+\]' "$LOG" 2>/dev/null | tail -1)
    # heartbeat every ~60s (6 ticks)
    if [ $((SECONDS % 60)) -lt "$INTERVAL" ]; then
      log "OK building ${prog:-?} load=$load"
    fi
    continue
  fi

  # success?
  if grep -q 'BUILD EXIT 0' "$LOG" 2>/dev/null; then
    log "SUCCESS — watcher idle"
    # keep watching in case someone kills
    sleep 60
    continue
  fi

  # failed or never started
  if grep -qE 'BUILD EXIT [1-9]|#### failed' "$LOG" 2>/dev/null || \
     ! grep -q 'BUILD START' "$LOG" 2>/dev/null; then
    fail_streak=$((fail_streak + 1))
    # need at least one failed cycle confirmed (avoid race at start)
    if [ "$fail_streak" -lt 2 ]; then
      log "idle/fail tick=$fail_streak (confirm)"
      continue
    fi
    err=$(grep -iE 'error:|not found|not allowed|arch//|#### failed|BUILD EXIT' "$LOG" 2>/dev/null | tail -5 | tr '\n' ' ')
    log "FAIL — fixing and restarting: $err"
    apply_known_fixes
    start_build
    fail_streak=0
    sleep 30
    continue
  fi

  # idle without clear status
  fail_streak=$((fail_streak + 1))
  if [ "$fail_streak" -ge 3 ]; then
    log "idle without build — restart"
    apply_known_fixes
    start_build
    fail_streak=0
  fi
done
