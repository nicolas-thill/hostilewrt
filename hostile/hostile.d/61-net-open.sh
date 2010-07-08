# net-open | Open network helper functions

#
# Copyright (C) 2009-2010 /tmp/lap <contact@tmplab.org>
#
# This is free software, licensed under the Exception General Public 
# License v2. See /COPYING for more information.
#

h_open_try_one_network() {
	h_log 1 "found open network (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"

	[ "$H_OP_MODE_sta" = "1" ] && h_sta_try "OPEN" "off"
}

h_open_try_all_networks() {
	for N in $(cat $H_NET_OPEN_F); do
		h_net_switch $N || continue
		h_open_try_one_network
	done
}

