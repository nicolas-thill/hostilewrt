#
# Copyright (C) 2009-2010 HostileWrt
#
# This is free software, licensed under the GNU General Public License v2.
# See /LICENSE for more information.
#

include $(TOPDIR)/rules.mk

PKG_NAME:=hostile
PKG_VERSION:=0.5.2
PKG_RELEASE:=1

PKG_SOURCE:=$(PKG_NAME)-$(PKG_VERSION).tar.gz
PKG_SOURCE_SUBDIR:=$(PKG_NAME)-$(PKG_VERSION)
PKG_SOURCE_PROTO:=git
PKG_SOURCE_URL:=http://github.com/psycho-nico/hostilewrt.git
PKG_SOURCE_VERSION:= $(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/hostile
  SECTION:=net
  CATEGORY:=Network
  DEPENDS:=+aircrack-ng +macchanger
  TITLE:=An automated wireless security audit tool
  URL:=http://hostile.nico-and-co.net/
  SUBMENU:=wireless
  PKGARCH:=all
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/hostile/conffiles
/etc/hostile.conf
endef

H_SRC_DIR:=$(PKG_BUILD_DIR)/hostile

define Package/hostile/install
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_BIN) $(H_SRC_DIR)/hostile.sh $(1)/usr/bin/hostile
	$(INSTALL_DIR) $(1)/usr/lib/hostile
	$(INSTALL_DATA) $(H_SRC_DIR)/hostile.d/*.sh $(1)/usr/lib/hostile/
	chmod 0755 $(1)/usr/lib/hostile/udhcpc.sh
	$(INSTALL_DIR) $(1)/usr/lib/hostile/dict
	$(INSTALL_DATA) $(H_SRC_DIR)/hostile.d/dict/*.dict $(1)/usr/lib/hostile/dict/
	$(INSTALL_DIR) $(1)/usr/lib/hostile/ssid
	$(INSTALL_DATA) $(H_SRC_DIR)/hostile.d/ssid/*.ssid $(1)/usr/lib/hostile/ssid/
	$(INSTALL_DIR) $(1)/etc
	$(INSTALL_DATA) $(H_SRC_DIR)/hostile.conf $(1)/etc/
	$(SED) 's|^\(H_LIB_D\)=.*$$$$|\1=/usr/lib/hostile|' \
	    -e 's|^\(H_LOG_F\)=.*$$$$|\1=/var/log/hostile.log|' \
	    -e 's|^\(H_PID_F\)=.*$$$$|\1=/var/run/hostile.pid|' \
	    -e 's|^\(H_RUN_D\)=.*$$$$|\1=/var/run/hostile|' \
		$(1)/etc/hostile.conf
	$(INSTALL_DIR) $(1)/etc/default
	$(INSTALL_DATA) ./files/hostile.default $(1)/etc/default/hostile
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_BIN) ./files/hostile.init $(1)/etc/init.d/hostile
endef

$(eval $(call BuildPackage,hostile))
