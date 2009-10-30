# h_wifi_madwifi

h_wifi_madwifi_startup() {
	H_AP_IF=ath0
	H_STA_IF=ath1
	H_MON_IF=ath2

	[ -n "$H_WIFI_MAC" ] && {
		H_WIFI_MAC_OLD=$(h_mac_get $H_WIFI_IF)
		h_mac_set $H_WIFI_IF $H_WIFI_MAC
	}
	H_WIFI_MAC=$(h_mac_get $H_WIFI_IF)
	h_log 1 "using interface: $H_WIFI_IF, mac address: $H_WIFI_MAC"

	[ "$H_OP_MODE_ap" = "1" ] && {
		wlanconfig $H_AP_IF create wlandev $H_WIFI_IF wlanmode ap >/dev/null 2>&1 \
			|| h_log 0 "can't create ap ($H_AP_IF) interface"
		H_AP_MAC=$(h_mac_get $H_AP_IF)
	}
	
	[ "$H_OP_MODE_sta" = "1" ] && {
		wlanconfig $H_STA_IF create wlandev $H_WIFI_IF wlanmode sta nosbeacon >/dev/null 2>&1 \
			|| h_log 0 "can't create sta ($H_STA_IF) interface"
		H_STA_MAC=$(h_mac_get $H_STA_IF)
	}

	wlanconfig $H_MON_IF create wlandev $H_WIFI_IF wlanmode monitor >/dev/null 2>&1 \
		|| h_log 0 "can't create monitor ($H_MON_IF) interface"
	H_MON_MAC=$(h_mac_get $H_MON_IF)

	return 0
}

h_wifi_madwifi_cleanup() {
	ifconfig $H_MON_IF down
	sleep 1
	wlanconfig $H_MON_IF destroy >/dev/null 2>&1

	[ "$H_OP_MODE_sta" = "1" ] && {
		ifconfig $H_STA_IF down
		sleep 1
		wlanconfig $H_STA_IF destroy >/dev/null 2>&1
	}
	
	[ "$H_OP_MODE_ap" = "1" ] && {
		ifconfig $H_AP_IF down
		sleep 1
		wlanconfig $H_AP_IF destroy >/dev/null 2>&1
	}
	
	[ -n "$H_WIFI_MAC_OLD" ] && {
		h_mac_set $H_WIFI_IF $H_WIFI_MAC_OLD
	}

	return 0
}

h_wifi_madwifi_detect() {
	[ -e /proc/sys/dev/ath ] && {
		[ "$H_WIFI_IF" = "auto" -a -e /proc/sys/dev/wifi0 ] \
			&& H_WIFI_IF=wifi0
		
		h_hook_register_handler on_wifi_startup h_wifi_madwifi_startup
		h_hook_register_handler on_wifi_cleanup h_wifi_madwifi_cleanup
	}

	return 0
}

h_hook_register_handler on_app_starting h_wifi_madwifi_detect
