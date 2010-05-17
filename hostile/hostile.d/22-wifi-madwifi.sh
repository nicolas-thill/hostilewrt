# wifi-madwifi

#
# Copyright (C) 2009-2010 /tmp/lap <contact@tmplab.org>
#
# This is free software, licensed under the Exception General Public 
# License v2. See /COPYING for more information.
#

h_wifi_madwifi_startup() {
	H_AP_IF=ath0
	H_STA_IF=ath1
	H_MON_IF=ath2

	if [ -n "$H_WIFI_MAC" ]; then
		H_WIFI_MAC_OLD=$(h_mac_get $H_WIFI_IF)
		h_mac_set $H_WIFI_IF $H_WIFI_MAC
	fi
	H_WIFI_MAC=$(h_mac_get $H_WIFI_IF)
	h_log 1 "using interface: $H_WIFI_IF, mac address: $H_WIFI_MAC"

	if [ "$H_OP_MODE_ap" = "1" ]; then
		h_run wlanconfig $H_AP_IF create wlandev $H_WIFI_IF wlanmode ap >/dev/null 2>&1 \
			|| h_log 0 "can't create ap ($H_AP_IF) interface"
		H_AP_MAC=$(h_mac_get $H_AP_IF)
		h_run iwconfig $H_AP_IF channel 1
		h_run iwconfig $H_AP_IF rate 54M
	fi
	
	if [ "$H_OP_MODE_sta" = "1" ]; then
		h_run wlanconfig $H_STA_IF create wlandev $H_WIFI_IF wlanmode sta nosbeacon >/dev/null 2>&1 \
			|| h_log 0 "can't create sta ($H_STA_IF) interface"
		H_STA_MAC=$(h_mac_get $H_STA_IF)
		h_run iwconfig $H_STA_IF channel 1
		h_run iwconfig $H_STA_IF rate 54M
	fi

	h_run wlanconfig $H_MON_IF create wlandev $H_WIFI_IF wlanmode monitor >/dev/null 2>&1 \
		|| h_log 0 "can't create monitor ($H_MON_IF) interface"
	H_MON_MAC=$(h_mac_get $H_MON_IF)
	h_run iwconfig $H_MON_IF channel 1
	h_run iwconfig $H_MON_IF rate 54M

	return 0
}

h_wifi_madwifi_cleanup() {
	h_run ifconfig $H_MON_IF down
	sleep 1
	h_run wlanconfig $H_MON_IF destroy >/dev/null 2>&1

	if [ "$H_OP_MODE_sta" = "1" ]; then
		h_run ifconfig $H_STA_IF down
		sleep 1
		h_run wlanconfig $H_STA_IF destroy >/dev/null 2>&1
	fi
	
	if [ "$H_OP_MODE_ap" = "1" ]; then
		h_run ifconfig $H_AP_IF down
		sleep 1
		h_run wlanconfig $H_AP_IF destroy >/dev/null 2>&1
	fi
	
	if [ -n "$H_WIFI_MAC_OLD" ]; then
		h_mac_set $H_WIFI_IF $H_WIFI_MAC_OLD
	fi

	return 0
}

h_wifi_madwifi_channel_change() {
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
			h_run iwconfig $H_AP_IF channel $new_channel
		fi
		if [ "$H_OP_MODE_sta" = "1" ]; then
			h_run iwconfig $H_STA_IF channel $new_channel
		fi
		h_run iwconfig $H_MON_IF channel $new_channel

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

h_wifi_madwifi_sta_startup() {
	local enc
	local key

	enc="$1"
	key="$2"

	case $enc in
	  OPEN)
		;;
	  WEP)
		;;
	  *)
		h_log 1 "Client: no support for '$enc' encryption (yet), sorry!"
		return 1
	esac

	h_log 1 "Client: configuring wireless (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"
	h_run ifconfig $H_STA_IF down
	h_run iwconfig $H_STA_IF ap "$H_CUR_BSSID"
	h_run iwconfig $H_STA_IF essid "$H_CUR_ESSID"
	case $enc in
	  OPEN)
		h_run iwconfig $H_STA_IF key off
		;;
	  WEP)
		h_run iwconfig $H_STA_IF key "$key"
		;;
	esac
	h_run ifconfig $H_STA_IF up
	
	return 0
}

h_wifi_madwifi_sta_cleanup() {
	h_log 1 "Client: deconfiguring wireless (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"
	h_run ifconfig $H_STA_IF down
	h_run iwconfig $H_STA_IF ap off
	h_run iwconfig $H_STA_IF essid off
}

h_wifi_madwifi_detect() {
	if [ -e /proc/sys/dev/ath ]; then
		if [ "$H_WIFI_IF" = "auto" -a -e /proc/sys/dev/wifi0 ]; then
			H_WIFI_IF=wifi0
		fi
		
		h_hook_register_handler on_wifi_startup h_wifi_madwifi_startup
		h_hook_register_handler on_wifi_cleanup h_wifi_madwifi_cleanup
		h_hook_register_handler on_wifi_channel_change h_wifi_madwifi_channel_change
		h_hook_register_handler on_wifi_sta_connect h_wifi_madwifi_sta_connect
		h_hook_register_handler on_wifi_sta_disconnect h_wifi_madwifi_sta_disconnect
	fi

	return 0
}

h_hook_register_handler on_app_starting h_wifi_madwifi_detect
