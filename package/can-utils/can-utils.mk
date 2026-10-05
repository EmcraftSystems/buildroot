################################################################################
#
# can-utils
#
################################################################################

CAN_UTILS_VERSION = 2021.08.0
CAN_UTILS_SITE = $(call github,linux-can,can-utils,v$(CAN_UTILS_VERSION))
CAN_UTILS_LICENSE = BSD-3-Clause or GPL-2.0
CAN_UTILS_LICENSE_FILES = LICENSES/BSD-3-Clause LICENSES/GPL-2.0-only.txt
CAN_UTILS_AUTORECONF = YES

ifeq ($(BR2_USE_MMU),)
CAN_UTILS_CONF_ENV += CFLAGS="$(TARGET_CFLAGS) -DCAN_UTILS_NO_MMU"
endif

$(eval $(autotools-package))
