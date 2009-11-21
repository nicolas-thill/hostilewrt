# h_net
# generic network helper functions

h_monitor_all() {
	local bssid
	local channel
	local n_open
	local n_wep
	local n_wpa

	h_log 1 "monitoring *ALL* traffic for $H_MONITOR_TIME_LIMIT seconds"
	
	if [ -n "$H_OPT_BSSID" ]; then
		bssid=$H_OPT_BSSID
	fi
	if [ -n "$H_OPT_CHANNEL" ]; then
		channel=$H_OPT_CHANNEL
	elif [ -n "$H_STA_CONNECTED" ]; then
		channel=$H_CUR_CHANNEL
	fi

	h_hook_call_handlers on_wifi_channel_change $channel

	h_capture_start h_capture --write ALL ${bssid:+--bssid $bssid} ${channel:+--channel $channel} -f 250 --output-format=csv,kismet
	sleep $H_MONITOR_TIME_LIMIT
	h_capture_stop
	
	sleep 1

	H_ALL_CSV_F=$(h_get_last_file ALL-??.csv)
	H_ALL_KIS_F=$(h_get_last_file ALL-??.kismet.csv)

	H_NET_OPEN_F=ALL-OPEN.txt
	H_NET_WEP_F=ALL-WEP.txt
	H_NET_WPA_F=ALL-WPA.txt
	H_NET_ESSIDS_F=ALL-ESSIDS.txt
	h_kis_get_networks_by_enc $H_ALL_KIS_F "O" >$H_NET_OPEN_F
	h_kis_get_networks_by_enc $H_ALL_KIS_F "WEP" >$H_NET_WEP_F
	h_kis_get_networks_by_enc $H_ALL_KIS_F "WPA" >$H_NET_WPA_F

	if [ -z "$H_CUR_COUNTRY" ]; then
		h_log 1 "guessing country code..."
		h_kis_get_essids $H_ALL_KIS_F >$H_NET_ESSIDS_F
		H_CUR_COUNTRY=$(h_stw_get_country $H_NET_ESSIDS_F)
		if [ -n "$H_CUR_COUNTRY" ]; then
			h_log 1 "my guess: $H_CUR_COUNTRY"
		else
			h_log 1 "no idea, using generic"
			H_CUR_COUNTRY="generic"
		fi
	fi

	n_open=$(wc -l <$H_NET_OPEN_F)
	n_wep=$(wc -l <$H_NET_WEP_F)
	n_wpa=$(wc -l <$H_NET_WPA_F)
	h_log 1 "found $n_open open, $n_wep WEP & $n_wpa WPA networks"
}


h_net_match_cb() {
	local value
	local pattern
	value="" # $1 is ignored, will be generated depending on the pattern
	pattern="$2"
	# if the pattern contains BSSID="...", then use BSSID for matching
	echo "$pattern" | grep -q 'BSSID=".*"' \
		&& value="BSSID=\"${H_NEW_BSSID}\""
	# if the pattern contains CHANNEL="...", then use CHANNEL for matching
	echo "$pattern" | grep -q 'CHANNEL=".*"' \
		&& value="${value}${value:+\s+}CHANNEL=\"${H_NEW_CHANNEL}\""
	# if the pattern contains ESSID="...", then use ESSID for matching
	echo "$pattern" | grep -q 'ESSID=".*"' \
		&& value="${value}${value:+\s+}ESSID=\"${H_NEW_ESSID}\""
	h_regex_match "$value" "$pattern"
}

h_net_switch() {
	local N

	N=$1
	H_NEW_BSSID=$(h_kis_get_network_bssid $H_ALL_KIS_F $N)
	H_NEW_CHANNEL=$(h_kis_get_network_channel $H_ALL_KIS_F $N)
	H_NEW_ESSID=$(h_kis_get_network_essid $H_ALL_KIS_F $N)

	if [ -n "$H_STA_CONNECTED" -a "$H_NEW_CHANNEL" != "$H_CUR_CHANNEL" ]; then
		h_log 1 "sta connected, using channel $H_CUR_CHANNEL, skipping network (bssid='$H_NEW_BSSID', channel=$H_NEW_CHANNEL, essid='$H_NEW_ESSID')"
		return 1
	fi

	if [ -n "$H_EXCL_F" ]; then
		for f in $H_EXCL_F; do
			if cat $f | grep -v "^#" | h_regex_loop_match "" h_net_match_cb; then
				h_log 2 "excluded network (bssid='$H_NEW_BSSID', channel=$H_NEW_CHANNEL, essid='$H_NEW_ESSID'), found in '$f'"
				return 1
			fi
		done
	fi
	if [ -n "$H_INCL_F" ]; then
		for f in $H_INCL_F; do
			if cat $f | grep -v "^#" | h_regex_loop_match "" h_net_match_cb; then
				h_log 2 "included network (bssid='$H_NEW_BSSID', channel=$H_NEW_CHANNEL, essid='$H_NEW_ESSID'), found in '$f'"
				break
			fi
		done
		h_log 2 "excluded network (bssid='$H_NEW_BSSID', channel=$H_NEW_CHANNEL, essid='$H_NEW_ESSID')"
		return 1
	fi
	H_CUR_BSSID="$H_NEW_BSSID"
	H_CUR_ESSID="$H_NEW_ESSID"
	h_hook_call_handlers on_wifi_channel_change $H_NEW_CHANNEL
	H_CUR_BASE_FNAME=$(h_get_sane_fname $H_CUR_BSSID)
	return 0
}
