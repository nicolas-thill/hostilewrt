# wifi-mac80211

#
# Copyright (C) 2009-2010 /tmp/lap <contact@tmplab.org>
#
# This is free software, licensed under the Exception General Public 
# License v2. See /COPYING for more information.
#

h_wifi_mac80211_startup() {
	H_AP_IF=wlan0
	H_STA_IF=wlan1
	H_MON_IF=wlan2

# XXX: fix mac spoofing with mac80211
#	if [ -n "$H_WIFI_MAC" ]; then
#		H_WIFI_MAC_OLD=$(h_mac_get $H_WIFI_IF)
#		h_mac_set $H_WIFI_IF $H_WIFI_MAC
#	fi
	H_WIFI_MAC=$(cat /sys/class/ieee80211/${H_WIFI_IF}/macaddress)
	h_log 1 "using interface: $H_WIFI_IF, mac address: $H_WIFI_MAC"

	if [ "$H_OP_MODE_ap" = "1" ]; then
		h_run iw phy $H_WIFI_IF interface add $H_AP_IF type managed >/dev/null 2>&1 \
			|| h_log 0 "can't create ap ($H_AP_IF) interface"
		H_AP_MAC=$(h_mac_get $H_AP_IF)
	fi

	if [ "$H_OP_MODE_sta" = "1" ]; then
		h_run iw phy $H_WIFI_IF interface add $H_STA_IF type managed >/dev/null 2>&1 \
			|| h_log 0 "can't create sta ($H_STA_IF) interface"
		H_STA_MAC=$(h_mac_get $H_STA_IF)
	fi

	h_run iw phy $H_WIFI_IF interface add $H_MON_IF type monitor >/dev/null 2>&1 \
		|| h_log 0 "can't create monitor ($H_MON_IF) interface"
	H_MON_MAC=$(h_mac_get $H_MON_IF)

	return 0
}

h_wifi_mac80211_cleanup() {
	h_run ifconfig $H_MON_IF down
	sleep 1
	h_run iw dev $H_MON_IF del

	if [ "$H_OP_MODE_sta" = "1" ]; then
		h_run ifconfig $H_STA_IF down
		sleep 1
		h_run iw dev $H_STA_IF del
	fi

	if [ "$H_OP_MODE_ap" = "1" ]; then
		h_run ifconfig $H_AP_IF down
		sleep 1
		h_run iw dev $H_AP_IF del
	fi

#	if [ -n "$H_WIFI_MAC_OLD" ]; then
#		h_mac_set $H_WIFI_IF $H_WIFI_MAC_OLD
#	fi

	return 0
}

h_wifi_mac80211_channel_change() {
	local new_channel
	local old_channel
	new_channel=$1
	old_channel=$H_CUR_CHANNEL

	if [ "$new_channel" != "$old_channel" ]; then
		h_log 1 "switching to channel: $new_channel"

		h_hook_call_handlers on_wifi_channel_changing $new_channel $old_channel

		if [ "$H_OP_MODE_ap" = "1" ]; then
			h_run ifconfig $H_AP_IF down
		fi
		if [ "$H_OP_MODE_sta" = "1" ]; then
			h_run ifconfig $H_STA_IF down
		fi
		h_run ifconfig $H_MON_IF down

		if [ "$H_OP_MODE_ap" = "1" ]; then
			h_run iw $H_AP_IF set channel $new_channel
		fi
		if [ "$H_OP_MODE_sta" = "1" ]; then
			h_run iw $H_STA_IF set channel $new_channel
		fi
		h_run iw $H_MON_IF set channel $new_channel

		if [ "$H_OP_MODE_ap" = "1" ]; then
			h_run ifconfig $H_AP_IF up
		fi
		if [ "$H_OP_MODE_sta" = "1" ]; then
			if [ -n "$H_STA_CONNECTED" ]; then
				h_run ifconfig $H_STA_IF up
			fi
		fi
		h_run ifconfig $H_MON_IF up

		h_hook_call_handlers on_wifi_channel_changed $new_channel $old_channel

		H_CUR_CHANNEL=$new_channel
	fi

	return 0
}

h_wifi_mac80211_detect() {
	if [ -e /sys/class/ieee80211 ]; then
		if [ "$H_WIFI_IF" = "auto" -a -e /sys/class/ieee80211/phy0 ]; then
			H_WIFI_IF=phy0
		fi
		
		h_hook_register_handler on_wifi_startup h_wifi_mac80211_startup
		h_hook_register_handler on_wifi_cleanup h_wifi_mac80211_cleanup
		h_hook_register_handler on_wifi_channel_change h_wifi_mac80211_channel_change
	fi

	return 0
}

h_hook_register_handler on_app_starting h_wifi_mac80211_detect
