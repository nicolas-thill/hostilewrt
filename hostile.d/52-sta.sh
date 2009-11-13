# STA

H_STA_UDHCPC_PID_F=$H_RUN_D/udhcpc.pid
H_STA_UDHCPC_SCRIPT_F=$H_LIB_D/udhcpc.sh

H_STA_PING_HOST="www.google.com"

H_STA_CONNECTED=

h_sta_start() {
	[ "$H_OP_MODE_sta" = "1" ] || return 0
	
	h_log 1 "starting sta mode"

	h_run iptables -t nat -A POSTROUTING -o $H_STA_IF -j MASQUERADE \
		|| return 1

	h_hook_register_handler on_app_ending h_sta_stop
	
	return 0
}

h_sta_stop() {
	h_log 1 "stopping sta mode"

	h_run iptables -t nat D POSTROUTING -o $H_STA_IF -j MASQUERADE
	h_run ifconfig $H_STA_IF down

	h_hook_unregister_handler on_app_ending h_sta_stop
	
	return 0
}

h_sta_check() {
	h_log 1 "checking client connectivity"

	h_run ping -q -c 3 -W 5 -w 15 -I $H_STA_IF $H_STA_PING_HOST
	if [ $? -ne 0 ]; then
		h_log 1 "not connected"
		unset H_STA_CONNECTED
		ifconfig $H_STA_IF down
		iwconfig $H_STA_IF ap off
		iwconfig $H_STA_IF essid off
		return 1
	fi
	
	h_log 1 "(still) connected"
	H_STA_CONNECTED=1

	return 0
}

h_sta_connect() {
	local enc
	local key

	enc="$1"
	key="$2"
	case $enc in
	  OPEN)
		key=off
		;;
	  WEP)
		;;
	  *)
		h_log 1 "no support for '$enc' encryption (yet), sorry!"
		return 1
	esac

	h_log 1 "configuring wireless (bssid='$H_CUR_BSSID', channel=$H_CUR_CHANNEL, essid='$H_CUR_ESSID')"
	h_run ifconfig $H_STA_IF down
	h_run iwconfig $H_STA_IF ap "$H_CUR_BSSID"
	h_run iwconfig $H_STA_IF essid "$H_CUR_ESSID"
	h_run iwconfig $H_STA_IF key "$key"
	h_run ifconfig $H_STA_IF up
	h_run iwpriv $H_STA_IF bgscan 0

	h_log 1 "requesting IP address via DHCP"
	h_run udhcpc -f -n -q -i $H_STA_IF -s $H_STA_UDHCPC_SCRIPT_F
	if [ $? -ne 0 ]; then
		h_log 1 "no address received"
		ifconfig $H_STA_IF down
		iwconfig $H_STA_IF ap off
		iwconfig $H_STA_IF essid off
		return 1
	fi
	return 0
}

h_sta_try() {
	local enc
	local key

	enc="$1"
	key="$2"
	
	if [ -n "$H_STA_CONNECTED" ]; then
		h_sta_check \
			|| return 1
	else
		h_sta_connect "$enc" "$key" && h_sta_check \
			|| return 1
	fi
	return 0
}

h_hook_register_handler on_app_started h_sta_start
