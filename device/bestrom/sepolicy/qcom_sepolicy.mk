-include hardware/qcom-caf/common/qcom_defs.mk
ifneq ($(wildcard device/qcom/sepolicy_vndr/sm8650/SEPolicy.mk),)
  include device/qcom/sepolicy_vndr/sm8650/SEPolicy.mk
else ifneq ($(wildcard device/qcom/sepolicy_vndr/SEPolicy.mk),)
  include device/qcom/sepolicy_vndr/SEPolicy.mk
endif
