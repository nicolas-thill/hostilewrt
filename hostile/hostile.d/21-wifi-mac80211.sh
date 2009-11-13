# h_wifi_mac80211

h_wifi_mac80211_startup() {
	H_AP_IF=wlan0
	H_STA_IF=wlan1
	H_MON_IF=wlan2

# XXX: fix mac spoofing with mac80211
#	[ -n "$H_WIFI_MAC" ] && {
#		H_WIFI_MAC_OLD=$(h_mac_get $H_WIFI_IF)
#		h_mac_set $H_WIFI_IF $H_WIFI_MAC
#	}
	H_WIFI_MAC=$(cat /sys/class/ieee80211/${H_WIFI_IF}/macaddress)
	h_log 1 "using interface: $H_WIFI_IF, mac address: $H_WIFI_MAC"

	[ "$H_OP_MODE_ap" = "1" ] && {
		h_run iw phy $H_WIFI_IF interface add $H_AP_IF type managed >/dev/null 2>&1 \
			|| h_log 0 "can't create ap ($H_AP_IF) interface"
		H_AP_MAC=$(h_mac_get $H_AP_IF)
	}

	[ "$H_OP_MODE_sta" = "1" ] && {
		h_run iw phy $H_WIFI_IF interface add $H_STA_IF type managed >/dev/null 2>&1 \
			|| h_log 0 "can't create sta ($H_STA_IF) interface"
		H_STA_MAC=$(h_mac_get $H_STA_IF)
	}

	h_run iw phy $H_WIFI_IF interface add $H_MON_IF type monitor >/dev/null 2>&1 \
		|| h_log 0 "can't create monitor ($H_MON_IF) interface"
	H_MON_MAC=$(h_mac_get $H_MON_IF)

	return 0
}

h_wifi_mac80211_cleanup() {
	h_run ifconfig $H_MON_IF down
	sleep 1
	h_run iw dev $H_MON_IF del

	[ "$H_OP_MODE_sta" = "1" ] && {
		h_run ifconfig $H_STA_IF down
		sleep 1
		h_run iw dev $H_STA_IF del
	}

	[ "$H_OP_MODE_ap" = "1" ] && {
		h_run ifconfig $H_AP_IF down
		sleep 1
		h_run iw dev $H_AP_IF del
	}

#	[ -n "$H_WIFI_MAC_OLD" ] && {
#		h_mac_set $H_WIFI_IF $H_WIFI_MAC_OLD
#	}

	return 0
}

h_wifi_mac80211_detect() {
	[ -e /sys/class/ieee80211 ] && {
		[ "$H_WIFI_IF" = "auto" -a -e /sys/class/ieee80211/phy0 ] \
			&& H_WIFI_IF=phy0
		
		h_hook_register_handler on_wifi_startup h_wifi_mac80211_startup
		h_hook_register_handler on_wifi_cleanup h_wifi_mac80211_cleanup
	}

	return 0
}

h_hook_register_handler on_app_starting h_wifi_mac80211_detect
