# STA

H_STA_UDHCPC_PID_F=$H_RUN_D/udhcpc.pid
H_STA_UDHCPC_SCRIPT_F=$H_LIB_D/udhcpc.sh

H_STA_PING_HOST="www.google.com"

H_STA_CONNECTED=

h_sta_startup() {
	[ "$H_OP_MODE_sta" = "1" ] || return 0
	
	h_log 1 "Client: starting"

	h_run iptables -t nat -A POSTROUTING -o $H_STA_IF -j MASQUERADE \
		|| return 1

	h_hook_register_handler on_app_ending h_sta_cleanup
	
	return 0
}

h_sta_cleanup() {
	h_log 1 "Client: stopping"

	h_run iptables -t nat -D POSTROUTING -o $H_STA_IF -j MASQUERADE
	h_run ifconfig $H_STA_IF down

	h_hook_unregister_handler on_app_ending h_sta_cleanup
	
	return 0
}

h_sta_check() {
	h_log 1 "Client: checking connectivity (trying to reach '$H_STA_PING_HOST')"

	h_run ping -q -c 3 -W 5 -w 15 -I $H_STA_IF $H_STA_PING_HOST
	if [ $? -ne 0 ]; then
		h_log 1 "Client: not connected"
		unset H_STA_CONNECTED
		h_hook_call_handlers on_wifi_sta_cleanup
		return 1
	fi
	
	h_log 1 "Client: (still) connected"
	H_STA_CONNECTED=1

	return 0
}

h_sta_connect() {
	local enc
	local key

	enc="$1"
	key="$2"

	h_hook_call_handlers on_wifi_sta_startup "$enc" "$key"

	h_log 1 "Client: requesting IP address via DHCP"
	h_run udhcpc -f -n -q -i $H_STA_IF -s $H_STA_UDHCPC_SCRIPT_F
	if [ $? -ne 0 ]; then
		h_log 1 "Client: no address received"
		h_hook_call_handlers on_wifi_sta_cleanup
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

h_hook_register_handler on_app_started h_sta_startup
