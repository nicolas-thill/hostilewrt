#!/bin/sh

H_ME=${0##*/}
H_MY_D=${0%/*}
H_MY_D=$(cd $H_MY_D; pwd)
H_MY_WD=$(pwd)
H_MY_PID=$$
H_VERSION="0.5.1"

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
$H_ME v$H_VERSION, Copyright (C) 2009-2010 /tmp/lap <contact@tmplab.org>

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
			-vvvv)
				H_OPT_VERBOSE=$(($H_OPT_VERBOSE + 4))
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

h_exec() {
	local cmd
	local rc

	cmd="$*"
	h_log 2 "running: $cmd"
	exec $cmd >/dev/null 2>&1
	rc=$?
	h_log 3 "returned $rc"
	return $rc
}

h_run() {
	local cmd
	local rc

	cmd="$*"
	h_log 2 "running: $cmd"
	$cmd >/dev/null 2>&1
	rc=$?
	h_log 3 "returned $rc"
	return $rc
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

	for M in $H_OP_MODES; do
		eval "H_OP_MODE_$M=1"
	done

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

h_mv_if_diff() {
	if [ "$1" -a "$2" ]
	then
		SRC=$1
		DEST=$2
		diff -q $SRC $DEST >/dev/null ; [ $? -eq 1 ] && mv $SRC $DEST
	fi
}

# XXX: TODO Move to event based, after each WEP/WPA network attack
# XXX: Use h_mv_if_diff() to backup the files...
h_backup_results() {
if [ "$H_BACKUP_TO_PERSISTENT_STORAGE" -a $H_BACKUP_TO_PERSISTENT_STORAGE -gt 0 ]
	then
		[ -z "$H_PERSISTENT_DIR" ] && H_PERSISTENT_DIR=/root/hostile/
		[ ! -d $H_PERSISTENT_DIR ] && mkdir -p $H_PERSISTENT_DIR
		cat $H_WEP_F $H_PERSISTENT_DIR/hostile-wep.txt 2>/dev/null | sort -u > /tmp/temp-wep.txt ; h_mv_if_diff /tmp/temp-wep.txt $H_PERSISTENT_DIR/hostile-wep.txt
		cat $H_WPA_F $H_PERSISTENT_DIR/hostile-wpa.txt 2>/dev/null | sort -u > /tmp/temp-wpa.txt ; h_mv_if_diff /tmp/temp-wpa.txt $H_PERSISTENT_DIR/hostile-wpa.txt
	fi
}

h_clean_run_d() {
	h_log 1 "limited storage space available, purging run files"
	h_run rm -f $H_CUR_BASE_FNAME-??.csv $H_CUR_BASE_FNAME-??.kismet.csv *.cap *.ivs *.wpa_hs *.xor
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
