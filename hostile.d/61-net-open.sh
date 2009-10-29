# h_net_open
# open network helper functions

h_open_try_one_network() {
	h_net_switch $1 || return 1
	h_net_allowed || return 1
	h_log 1 "found open network (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"

	[ "$H_OP_MODE_sta" = "1" ] && h_sta_try "OPEN" "off"
}

h_open_try_all_networks() {
	for N in $(cat $H_NET_OPEN_F); do
		h_open_try_one_network $N
	done
}

