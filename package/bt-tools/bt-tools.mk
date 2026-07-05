################################################################################
#
# bt-tools
#
# Legacy Bluetooth user-space stack (BlueZ 2.25 + OpenOBEX + obexftp), built
# from an in-tree source tree supplied via BT_TOOLS_OVERRIDE_SRCDIR (written to
# $(O)/local.mk by the project Rules.make), the same way busybox is built.
# The noMMU build redefines fork() to vfork().
#
################################################################################

BT_TOOLS_VERSION = 2.25
# No SITE/SOURCE: the source tree is always supplied via
# BT_TOOLS_OVERRIDE_SRCDIR, so there is nothing to download. SOURCE must be
# forced empty (buildroot defaults it to <name>-<version>.tar.gz, which would
# then demand a SITE).
BT_TOOLS_SOURCE =
BT_TOOLS_LICENSE = GPL-2.0+, LGPL-2.1+
BT_TOOLS_DEPENDENCIES = host-autoconf host-automake host-libtool host-pkgconf

# Sub-component directories inside the source tree.
BT_TOOLS_BLUEZ_LIBS  = bluez-libs-2.25
BT_TOOLS_BLUEZ_UTILS = bluez-utils-2.25
BT_TOOLS_OPENOBEX    = openobex-1.5
BT_TOOLS_OBEXFTP     = obexftp-0.23

# uClibc on noMMU FDPIC does not export fork(); the 2006-era stack is built
# with fork redefined to vfork().
BT_TOOLS_CFLAGS = $(TARGET_CFLAGS) -Dfork=vfork

# Everything installs under /usr/local (the prefix these components use), into
# the staging tree first so each component finds the previous one, then into
# the target tree.
BT_TOOLS_PREFIX = /usr/local
BT_TOOLS_STAGE  = $(STAGING_DIR)$(BT_TOOLS_PREFIX)

BT_TOOLS_CONF_OPTS = \
	--host=$(GNU_TARGET_NAME) \
	--build=$(GNU_HOST_NAME) \
	--prefix=$(BT_TOOLS_PREFIX)

# buildroot's autotools infra adds the uclinuxfdpiceabi host_os to libtool's
# "linux*" cases in the generated configure (its
# CONFIGURE_FIX_UCLINUXFDPICEABI_HOOK). generic-package does not, so we replicate
# the same sed. Without it libtool decides "shared libraries: no" for this host
# and builds only static .a, but the rootfs links the BT stack as shared .so.
# Run on each component's configure, after autoreconf where applicable.
# Uses ',' as the sed delimiter (not buildroot's '#'): in a make variable
# assignment '#' starts a comment and would truncate the value.
BT_TOOLS_FIX_FDPIC = sed -Ei 's,((\s|^)linux\*\B),\1 | uclinuxfdpiceabi,' configure

# Install-step make environment. On "make install" libtool relinks the
# inter-dependent libraries to embed the final /usr/local rpath, and for a
# sibling dependency it emits a bare -L/usr/local/lib (that dependency's
# libdir). The real library is always resolved from the sysroot -L that libtool
# lists first, so the bare path is inert here -- but the toolchain wrapper
# errors on it. The bare path is unavoidable because the legacy layout installs
# under /usr/local (not the sysroot's default libdir), so downgrade the check to
# a warning for the install relink only (compile/link keep the full check).
BT_TOOLS_INSTALL_ENV = $(TARGET_MAKE_ENV) BR_COMPILER_PARANOID_UNSAFE_PATH=

define BT_TOOLS_BUILD_CMDS
	# Built with $(MAKE1) (serial): these 2006 autotools trees have missing
	# intra-directory deps (e.g. rfcomm's bison/flex parser.h) that race under
	# the parallel make inherited from the project build.
	# bluez-libs -> libbluetooth
	cd $(@D)/$(BT_TOOLS_BLUEZ_LIBS) && \
		$(BT_TOOLS_FIX_FDPIC) && \
		$(TARGET_CONFIGURE_OPTS) CFLAGS="$(BT_TOOLS_CFLAGS)" \
		./configure $(BT_TOOLS_CONF_OPTS)
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_BLUEZ_LIBS)
	$(BT_TOOLS_INSTALL_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_BLUEZ_LIBS) \
		install DESTDIR=$(STAGING_DIR)

	# bluez-utils -> hcid, sdpd, hcitool, sdptool, rfcomm
	# --with-usb / --with-dbus point the optional-dependency probes at the
	# staging tree. Without them their prefix defaults to /usr/local and the
	# configure macros inject bare -I/usr/local/include / -L/usr/local/lib,
	# which the cross toolchain wrapper rejects as unsafe host paths. usb.h
	# and libdbus are absent from staging, so both features stay disabled
	# (UART HCI, no D-Bus), which is what the target needs.
	# --sysconfdir=/etc --localstatedir=/var compile hcid's CONFIGDIR as
	# /etc/bluetooth (and STORAGEDIR /var/lib/bluetooth). With --prefix=/usr/local
	# they would otherwise be /usr/local/etc|var; the rootfs ships the config in
	# /etc/bluetooth (as the legacy prefix-less build produced).
	cd $(@D)/$(BT_TOOLS_BLUEZ_UTILS) && \
		$(BT_TOOLS_FIX_FDPIC) && \
		$(TARGET_CONFIGURE_OPTS) CFLAGS="$(BT_TOOLS_CFLAGS)" \
		./configure $(BT_TOOLS_CONF_OPTS) --with-bluez=$(BT_TOOLS_STAGE) \
			--with-usb=$(BT_TOOLS_STAGE) --with-dbus=$(BT_TOOLS_STAGE) \
			--sysconfdir=/etc --localstatedir=/var
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_BLUEZ_UTILS)
	$(BT_TOOLS_INSTALL_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_BLUEZ_UTILS) \
		install DESTDIR=$(STAGING_DIR)

	# openobex (kept at -O0). Two things are needed for the Bluetooth
	# transport to be detected and compiled in:
	#  1. The host_os is "uclinuxfdpiceabi", which does NOT match these
	#     2006-era configure "case $host in *-*-linux*)" blocks, so the whole
	#     bluez/usb detection is skipped. The sed broadens the case to also
	#     match *-*-uclinux*. (Idempotent: the rewritten line no longer
	#     contains the "*-*-linux*)" substring.)
	#  2. BLUETOOTH_CFLAGS/_LIBS are deliberately NOT pre-set: configure
	#     resolves bluez via pkg-config (bluez.pc in staging, found through
	#     PKG_CONFIG_PATH; buildroot's pkg-config wrapper sysroot-prefixes the
	#     paths). Pre-setting them makes PKG_CHECK_MODULES skip its probe,
	#     leaving bluez_found unset so HAVE_BLUETOOTH (gated on it) is never
	#     defined and the transport is silently dropped.
	cd $(@D)/$(BT_TOOLS_OPENOBEX) && \
		sed -i 's/\*-\*-linux\*)/*-*-linux* | *-*-uclinux*)/' acinclude.m4 && \
		autoreconf --force --install && automake && \
		$(BT_TOOLS_FIX_FDPIC) && \
		$(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(BT_TOOLS_CFLAGS) -O0" \
		PKG_CONFIG_PATH="$(BT_TOOLS_STAGE)/lib/pkgconfig" \
		./configure $(BT_TOOLS_CONF_OPTS) --disable-usb --enable-bluetooth
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_OPENOBEX)
	$(BT_TOOLS_INSTALL_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_OPENOBEX) \
		install DESTDIR=$(STAGING_DIR)

	# obexftp -> obexftp, obexftpd, libobexftp/libbfb/libmulticobex
	rm -f $(BT_TOOLS_STAGE)/lib/*.la
	# Same two fixes as openobex above: broaden the *-*-linux* host case to
	# match *-*-uclinux* (otherwise bluez detection is skipped), and leave
	# OPENOBEX_*/BLUETOOTH_* unset so PKG_CHECK_MODULES runs and sets
	# bluez_found. Without HAVE_BLUETOOTH, client.c falls into its Win32
	# (#else) branch and fails on WSAESOCKTNOSUPPORT.
	# PERL=/PYTHON=/RUBY=/TCLSH= are forced empty: the SWIG language-binding
	# subdirs are gated on AM_CONDITIONAL([ENABLE_PERL], [test x"$$PERL" != x""])
	# etc. -- the program variable, NOT --disable-perl. buildroot exports PERL
	# in the environment, so without this the perl binding is built (with the
	# host compiler) despite --disable-perl and fails to find the cross headers.
	cd $(@D)/$(BT_TOOLS_OBEXFTP) && \
		sed -i 's/\*-\*-linux\*)/*-*-linux* | *-*-uclinux*)/' acinclude.m4 && \
		autoreconf --force --install && automake && \
		$(BT_TOOLS_FIX_FDPIC) && \
		$(TARGET_CONFIGURE_OPTS) \
		CFLAGS="$(BT_TOOLS_CFLAGS)" \
		PKG_CONFIG_PATH="$(BT_TOOLS_STAGE)/lib/pkgconfig" \
		PERL= PYTHON= RUBY= TCLSH= \
		./configure $(BT_TOOLS_CONF_OPTS) \
			--disable-perl --disable-python --disable-ruby --disable-tcl \
			--enable-bluetooth
	$(TARGET_MAKE_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_OBEXFTP)
	$(BT_TOOLS_INSTALL_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_OBEXFTP) \
		install DESTDIR=$(STAGING_DIR)
endef

define BT_TOOLS_INSTALL_TARGET_CMDS
	$(BT_TOOLS_INSTALL_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_BLUEZ_LIBS)  install DESTDIR=$(TARGET_DIR)
	$(BT_TOOLS_INSTALL_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_BLUEZ_UTILS) install DESTDIR=$(TARGET_DIR)
	$(BT_TOOLS_INSTALL_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_OPENOBEX)    install DESTDIR=$(TARGET_DIR)
	$(BT_TOOLS_INSTALL_ENV) $(MAKE1) -C $(@D)/$(BT_TOOLS_OBEXFTP)     install DESTDIR=$(TARGET_DIR)
	rm -f $(TARGET_DIR)$(BT_TOOLS_PREFIX)/lib/*.la
endef

$(eval $(generic-package))
