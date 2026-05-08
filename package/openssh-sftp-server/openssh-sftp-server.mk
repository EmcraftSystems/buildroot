################################################################################
#
# openssh-sftp-server
#
# Builds only the sftp-server binary from OpenSSH. This is safe on noMMU
# targets because sftp-server never calls fork().
#
################################################################################

OPENSSH_SFTP_SERVER_VERSION_MAJOR = 9.1
OPENSSH_SFTP_SERVER_VERSION_MINOR = p1
OPENSSH_SFTP_SERVER_VERSION = $(OPENSSH_SFTP_SERVER_VERSION_MAJOR)$(OPENSSH_SFTP_SERVER_VERSION_MINOR)
OPENSSH_SFTP_SERVER_SOURCE = openssh-$(OPENSSH_SFTP_SERVER_VERSION).tar.gz
OPENSSH_SFTP_SERVER_SITE = http://ftp.openbsd.org/pub/OpenBSD/OpenSSH/portable
OPENSSH_SFTP_SERVER_LICENSE = BSD-3-Clause, BSD-2-Clause, Public Domain
OPENSSH_SFTP_SERVER_LICENSE_FILES = LICENCE

OPENSSH_SFTP_SERVER_CONF_ENV = \
	LD="$(TARGET_CC)" \
	LDFLAGS="$(TARGET_CFLAGS)"

OPENSSH_SFTP_SERVER_CONF_OPTS = \
	--sysconfdir=/etc/ssh \
	--without-sandbox \
	--without-pam \
	--without-selinux \
	--without-audit \
	--without-openssl \
	--without-ssl-engine \
	--disable-lastlog \
	--disable-utmp \
	--disable-utmpx \
	--disable-wtmp \
	--disable-wtmpx

ifeq ($(BR2_TOOLCHAIN_SUPPORTS_PIE),)
OPENSSH_SFTP_SERVER_CONF_OPTS += --without-pie
endif

OPENSSH_SFTP_SERVER_DEPENDENCIES = host-pkgconf zlib

# Only build sftp-server. Use -ffunction-sections/-fdata-sections with
# --gc-sections so the linker drops unreferenced functions from libssh.a
# (notably misc.c:subprocess() which calls fork()). This avoids the
# fork link error on noMMU targets without any stub or defsym hack.
define OPENSSH_SFTP_SERVER_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D) \
		CFLAGS="$(TARGET_CFLAGS) -ffunction-sections -fdata-sections" \
		LD="$(TARGET_CC) -Wl,--gc-sections" \
		sftp-server
endef

define OPENSSH_SFTP_SERVER_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0755 $(@D)/sftp-server $(TARGET_DIR)/usr/libexec/sftp-server
endef

$(eval $(autotools-package))
