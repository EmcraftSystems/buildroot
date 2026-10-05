################################################################################
#
# can-tests
#
################################################################################

CAN_TESTS_VERSION = 2023.05.0
CAN_TESTS_SITE = $(call github,linux-can,can-tests,v$(CAN_TESTS_VERSION))
CAN_TESTS_LICENSE = GPL-2.0 or BSD-3-Clause

# cansniffer and canfdtest are also built by can-utils, which installs them.
CAN_TESTS_PROGRAMS = \
	bcm/tst-bcm-cycle bcm/tst-bcm-dump bcm/tst-bcm-filter bcm/tst-bcm-rtr \
	bcm/tst-bcm-rx-sendto bcm/tst-bcm-single bcm/tst-bcm-throttle \
	bcm/tst-bcm-tx-sendto bcm/tst-bcm-tx_delete bcm/tst-bcm-tx_read \
	bcm/tst-bcmfd-cycle bcm/tst-bcmfd-filter gw/gwtest \
	netlayer/tst-filter netlayer/tst-filter-master netlayer/tst-filter-server \
	netlayer/tst-packet netlayer/tst-proc netlayer/tst-rcv-own-msgs \
	raw/canecho raw/canpump raw/tst-err raw/tst-raw raw/tst-raw-filter \
	raw/tst-raw-sockopt raw/tst-raw-sendto

# CPPFLAGS stays the Makefile's own: it carries -Iinclude -Ilib.
define CAN_TESTS_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) CC="$(TARGET_CC)" \
		CFLAGS="$(TARGET_CFLAGS)" LDFLAGS="$(TARGET_LDFLAGS)" \
		$(CAN_TESTS_PROGRAMS)
endef

define CAN_TESTS_INSTALL_TARGET_CMDS
	$(foreach p,$(CAN_TESTS_PROGRAMS),
		$(INSTALL) -D -m 0755 $(@D)/$(p) $(TARGET_DIR)/usr/sbin/$(notdir $(p))
	)
endef

$(eval $(generic-package))
