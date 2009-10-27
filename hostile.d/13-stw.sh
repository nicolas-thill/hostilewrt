#!/bin/sh
# WEP Dict size
# 001 : 5k == 1mn @ 7 tests per seconds

H_STW_D=$H_LIB_D/ssid-to-wordlist

h_stw_get_match_count() {
	local current_f
	local country_f
	local current
	local count
	current_f=$1
	country_f=$2
	count=0
	cat $current_f | while [ true ]; do
		IFS= read current
		if [ -z "$current" ]; then
			echo "$count"
			break
		fi
		cat $country_f | grep -v "^#" | h_regex_loop_match $current \
			&& count=$((count + 1))
	done
}

h_stw_get_country() {
	local current_f
	local country_f
	local country
	local f
	current_f=$1
	for country_f in $H_STW_D/*.ssid; do
		f=${country_f##*/}
		country=${f%%.ssid}
		count=$(h_stw_get_match_count $current_f $country_f)
		res="$res\n$count $country"
	done
	echo -e "$res" | sort -n -r | head -n 1 | awk '{ print $2; }'
}
