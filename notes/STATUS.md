# BestROM A17 progress snapshot

Generated (UTC): 2026-07-19T15:57:41Z

## Goal
- Bootable zip for POCO F6 (peridot) via GuidixX CLO path
- Real system_dlkm / vendor_dlkm (full source kernel)
- Single ROM source: BestROM only

## Branches pushed
- Mohithash/device_xiaomi_peridot @ bestrom-a17
- Mohithash/android_vendor_bestrom @ bestrom-a17
- Mohithash/bestrom_a17_progress @ bestrom-a17

## Build host
- ServerHive arcane, tree: /serverhive/sal/bestrom-a17
- Auto-check: bestrom_auto_10s.sh every 10s
- Jobs: bacon -j16/-j24

## Host at snapshot
- load: 489.01 583.14 558.94
- tmux: bestrom: 1 windows (created Sun Jul 19 15:56:24 2026);

## Recent build log (tail)
```
TARGET_CPU_VARIANT=generic
HOST_OS=linux
HOST_OS_EXTRA=Linux-6.8.0-136-generic-x86_64-Ubuntu-24.04.4-LTS
HOST_CROSS_OS=windows
BUILD_ID=CP2A.260605.016
OUT_DIR=out
SOONG_ONLY=false
SOONG_INCREMENTAL_ANALYSIS=true
============================================
[1/1 100%] bootstrap blueprint
Running globs...
ninja: 
ninja: SISO_EXPERIMENTS=fallback-on-exec-error enabled
SISO_EXPERIMENTS=ignore-missing-out-in-depfile enabled

ninja: ignore missing out error in depfile 

ninja:  0.54s Build Succeeded: 0 steps - 0.00/s

device/xiaomi/peridot/BoardConfig.mk was modified, regenerating...
device/bestrom/sepolicy/qcom_sepolicy.mk was modified, regenerating...
[2/2 100%] initializing Make module parser
[3/19  15%] including out/soong/installs-bestrom_peridot.mk
[4/19  21%] including out/soong/Android-bestrom_peridot.mk
[5/19  26%] including build/make/target/board/android-info.mk
[6/19  31%] including bootable/deprecated-ota/updater/Android.mk
[7/19  36%] including device/amlogic/yukawa/Android.mk
[8/19  42%] including device/linaro/dragonboard/Android.mk
[9/19  47%] including device/linaro/hikey/Android.mk
[10/19  52%] including hardware/broadcom/libbt/Android.mk
[11/19  57%] including hardware/broadcom/wlan/bcmdhd/Android.mk
[12/19  63%] including hardware/invensense/Android.mk
[13/19  68%] including hardware/qcom-caf/sm8650/display/Android.mk
[14/19  73%] including hardware/qcom-caf/wlan/Android.mk
[15/19  78%] including hardware/qcom/wlan/Android.mk
[16/19  84%] including hardware/synaptics/wlan/synadhd/Android.mk
[17/19  89%] including kernel/xiaomi/sm8635-modules/Android.mk
[18/19  94%] including vendor/xiaomi/peridot/Android.mk
[19/19 100%] including out/soong/late-bestrom_peridot.mk
[20/20 100%] finishing Make module rules
```

## Known fixes applied
- Absolute HOSTCC/HOSTCXX/CC clang-r584948b
- KERNEL_MAKE_CMD prebuilts/build-tools make
- KERNEL_ARCH/TARGET_KERNEL_ARCH arm64
- pahole-flags.sh stub
- Voltage BoardConfig includes commented
- device/bestrom/sepolicy/qcom_sepolicy.mk wrapper
