# h_wifi_mac80211

h_wifi_mac80211_startup() {
	H_WIFI_IF=wlan0
	H_AP_IF=ath0
	H_STA_IF=ath1
	H_MON_IF=mon0

	[ -n "$H_MAC" ] && {
		H_MAC_OLD=$(h_mac_get $H_WIFI_IF)
		h_mac_set $H_WIFI_IF $H_MAC
	}
	H_MAC=$(h_mac_get $H_WIFI_IF)
	h_log "using interface: $H_WIFI_IF, mac address: $H_MAC"

	iw dev $H_WIFI_IF interface add $H_AP_IF type ibss
	H_AP_MAC=$(h_mac_get $H_AP_IF)

	iw dev $H_WIFI_IF interface add $H_STA_IF type managed
	H_STA_MAC=$(h_mac_get $H_STA_IF)

	iw dev $H_WIFI_IF interface add $H_MON_IF type monitor
	H_MON_MAC=$(h_mac_get $H_MON_IF)
}

h_wifi_mac80211_cleanup() {
	ifconfig $H_MON_IF down
	sleep 1
	iw dev $H_MON_IF del

	ifconfig $H_STA_IF down
	sleep 1
	iw dev $H_STA_IF del

	ifconfig $H_AP_IF down
	sleep 1
	iw dev $H_AP_IF del

	[ -n "$H_MAC_OLD" ] && {
		h_mac_set $H_WIFI_IF $H_MAC_OLD
	}
}
