#!/usr/bin/env bash
# Start BestROM A17 bacon inside byobu/tmux — admin-friendly, low resource.
# Usage (on server as sal):
#   bash /serverhive/sal/bin/bestrom_byobu_start.sh
#   byobu attach -t bestrom
set -uo pipefail

export HOME=/serverhive/sal
# Do NOT set BYOBU_DISABLE=1 — we want a real session
unset BYOBU_DISABLE

TREE=/serverhive/sal/bestrom-a17
SESSION=bestrom
# Cap parallel jobs — 48 saturates the shared ServerHive host
JOBS="${BESTROM_JOBS:-16}"
LOGDIR=/serverhive/sal/logs
LOG=$LOGDIR/bestrom_guidix_build.log
mkdir -p "$LOGDIR" "$TREE/out/host/linux-x86/bin"

echo "=== stop previous BestROM build processes (sal only) ==="
pkill -u sal -f 'bestrom_auto_fix_loop' 2>/dev/null || true
pkill -u sal -f 'bestrom_guidix_build' 2>/dev/null || true
pkill -u sal -f '/bestrom-a17/out/soong_ui' 2>/dev/null || true
pkill -u sal -f 'siso.*bestrom_peridot' 2>/dev/null || true
pkill -u sal -f 'siso.*combined-bestrom' 2>/dev/null || true
sleep 2

# Host DTC helpers (lightweight; no rebuild)
HOSTBIN=$TREE/out/host/linux-x86/bin
for t in fdtput fdtget fdtdump fdtoverlay dtc; do
  [ -x "/usr/bin/$t" ] && ln -sfn "/usr/bin/$t" "$HOSTBIN/$t"
done
[ -x "$HOSTBIN/fdtoverlay" ] && ln -sfn "$HOSTBIN/fdtoverlay" "$HOSTBIN/fdtoverlaymerge"
VOS_PRE=/serverhive/sal/voltage/prebuilts/kernel-build-tools/linux-x86/bin
if [ -x "$VOS_PRE/ufdt_apply_overlay" ] && [ ! -x "$HOSTBIN/ufdt_apply_overlay" ]; then
  cp -f "$VOS_PRE/ufdt_apply_overlay" "$HOSTBIN/ufdt_apply_overlay"
  chmod +x "$HOSTBIN/ufdt_apply_overlay"
fi

# Kill leftover byobu/tmux session with same name
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "Killing old tmux session: $SESSION"
  tmux kill-session -t "$SESSION" 2>/dev/null || true
fi

# Wrapper run inside the session
cat > /serverhive/sal/bin/bestrom_byobu_inner.sh << EOF
#!/usr/bin/env bash
set -uo pipefail
export HOME=/serverhive/sal
export USE_CCACHE=1
export CCACHE_DIR=/serverhive/sal/.ccache
export CCACHE_EXEC=\$(command -v ccache || true)
export ALLOW_MISSING_DEPENDENCIES=true
export SOONG_ALLOW_MISSING_DEPENDENCIES=true
export SKIP_ABI_CHECKS=true
export LLVM_PARALLEL_LINK_JOBS=4
# Keep parallel compile modest on shared host
export NINJA_STATUS='[%f/%t %p] '
JOBS=${JOBS}
TREE=/serverhive/sal/bestrom-a17
LOG=/serverhive/sal/logs/bestrom_guidix_build.log
HOSTBIN=\$TREE/out/host/linux-x86/bin
export PATH="\$HOSTBIN:\$PATH"

cd "\$TREE" || exit 1
# re-link host tools each start (installclean-safe)
for t in fdtput fdtget fdtdump fdtoverlay dtc; do
  [ -x /usr/bin/\$t ] && ln -sfn /usr/bin/\$t \$HOSTBIN/\$t
done
[ -x \$HOSTBIN/fdtoverlay ] && ln -sfn \$HOSTBIN/fdtoverlay \$HOSTBIN/fdtoverlaymerge
[ -x /serverhive/sal/voltage/prebuilts/kernel-build-tools/linux-x86/bin/ufdt_apply_overlay ] && \
  cp -f /serverhive/sal/voltage/prebuilts/kernel-build-tools/linux-x86/bin/ufdt_apply_overlay \$HOSTBIN/ 2>/dev/null

echo "=== BestROM A17 bacon in byobu session 'bestrom' ===" | tee "\$LOG"
echo "HOST=\$(hostname) JOBS=\$JOBS START=\$(date -u)" | tee -a "\$LOG"
echo "Attach: byobu attach -t bestrom   OR   tmux attach -t bestrom" | tee -a "\$LOG"

set +u
source build/envsetup.sh
[ -f vendor/bestrom/build/envsetup.sh ] && source vendor/bestrom/build/envsetup.sh
export ALLOW_MISSING_DEPENDENCIES=true
export SOONG_ALLOW_MISSING_DEPENDENCIES=true

LUNCH=""
for try in bestrom_peridot-trunk_staging-userdebug bestrom_peridot-userdebug bestrom_peridot-trunk_staging-user; do
  if lunch "\$try" >>"\$LOG" 2>&1; then
    LUNCH=\$try
    break
  fi
done
if [ -z "\$LUNCH" ]; then
  echo "FATAL: lunch failed" | tee -a "\$LOG"
  echo BUILD_EXIT=2 > /serverhive/sal/logs/bestrom_guidix_exit.txt
  exec bash
fi
echo "LUNCH=\$LUNCH" | tee -a "\$LOG"
export ALLOW_MISSING_DEPENDENCIES=true

echo "=== m bacon -j\$JOBS \$(date -u) ===" | tee -a "\$LOG"
set +e
# unbuffered-ish: stdbuf if present
if command -v stdbuf >/dev/null; then
  stdbuf -oL -eL m bacon -j"\$JOBS" 2>&1 | tee -a "\$LOG"
  RC=\${PIPESTATUS[0]}
else
  m bacon -j"\$JOBS" 2>&1 | tee -a "\$LOG"
  RC=\${PIPESTATUS[0]}
fi
set -e
echo "=== BUILD EXIT \$RC \$(date -u) ===" | tee -a "\$LOG"
echo "BUILD_EXIT=\$RC" > /serverhive/sal/logs/bestrom_guidix_exit.txt
PROD=out/target/product/peridot
ls -lah "\$PROD"/*.zip 2>/dev/null | tee -a "\$LOG"
du -sh "\$PROD"/system_dlkm "\$PROD"/vendor_dlkm 2>/dev/null | tee -a "\$LOG"
if [ "\$RC" -eq 0 ]; then
  Z=\$(ls -t "\$PROD"/*ota*.zip "\$PROD"/bestrom*.zip 2>/dev/null | head -1 || true)
  [ -n "\$Z" ] && cp -v "\$Z" /var/www/html/sal/ 2>/dev/null || true
fi
echo "Shell left open in byobu for inspection. Type exit to leave."
exec bash
EOF
chmod +x /serverhive/sal/bin/bestrom_byobu_inner.sh

# Start detached byobu/tmux session
# byobu is a wrapper around tmux on this host
byobu new-session -d -s "$SESSION" "bash /serverhive/sal/bin/bestrom_byobu_inner.sh"
sleep 2
echo "=== sessions ==="
tmux ls 2>&1 || byobu list-sessions 2>&1
echo
echo "Started BestROM in byobu session: $SESSION  (JOBS=$JOBS)"
echo "  Attach:  byobu attach -t $SESSION"
echo "  Or:      tmux attach -t $SESSION"
echo "  Log:     $LOG"
echo "  Detach:  Ctrl-a d  (byobu) / Ctrl-b d (tmux)"
echo DONE
