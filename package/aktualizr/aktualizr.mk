################################################################################
#
# Aktualizr
#
################################################################################

AKTUALIZR_VERSION = ec8bd5758fe71aa606082c614eb2e05cd6798a1d
AKTUALIZR_SITE = https://github.com/toradex/aktualizr.git
AKTUALIZR_SITE_METHOD = git

AKTUALIZR_LICENSE = MPL-2.0
AKTUALIZR_LICENSE_FILES = LICENSE
AKTUALIZR_DEPENDENCIES = boost libcurl openssl libarchive libsodium sqlite jsoncpp

AKTUALIZR_GIT_SUBMODULES = YES
AKTUALIZR_SUPPORTS_IN_SOURCE_BUILD = NO

AKTUALIZR_CONF_OPTS = \
	-DCMAKE_POLICY_VERSION_MINIMUM=3.5

$(eval $(cmake-package))
