# STA

H_STA_UDHCPC_PID_F=$H_RUN_D/hostile-udhcpc.pid
H_STA_UDHCPC_SCRIPT_F=/dev/null

h_sta_start() {
	local bssid
	local channel
	local essid
	local enc
	local key
	local cmd
	h_log "starting: Client"
	bssid=$1
	channel=$2
	essid=$3
	enc=$4
	key=$5
	if [ $end = "WEP" ]; then
		h_log "using: bssid=$bssid, essid='$essid' & key='$key' for client mode"
		ifconfig $H_STA_IF down
		iwconfig $H_STA_IF ap "$bssid"
		iwconfig $H_STA_IF essid "$essid"
		iwconfig $H_STA_IF enc "$enc"
		iwconfig $H_STA_IF key "$key"
		cmd="udhcpc -f -R -i $H_STA_IF -p $H_STA_UDHCPC_PID_F -s $H_STA_UDHCPC_SCRIPT_F"
		h_log "running: $cmd"
		$cmd >/dev/null 2>&1 &
		cmd="iptables -t nat -A POSTROUTING -o $H_STA_IF -j MASQUERADE"
		h_log "running: $cmd"
		$cmd >/dev/null 2>&1
		h_hook_register_handler on_app_ending h_sta_stop
		h_hook_register_handler on_channel_changing h_sta_stop
	else
		h_log "no support for encryption '$enc' (yet), sorry!"
	fi
	return 0
}

h_sta_stop() {
	local pid
	local cmd
	h_log "stopping: Client"
	cmd="iptables -t nat D POSTROUTING -o $H_STA_IF -j MASQUERADE"
	h_log "running: $cmd"
	$cmd >/dev/null 2>&1
	pid=$(cat $H_STA_UDHCPC_PID_F 2>&1)
	if [ -n "$pid" ]; then
		kill -TERM $pid >/dev/null 2>&1
		sleep 1
		echo "" > $H_STA_UDHCPC_PID_F
		ifconfig $H_STA_IF down
	fi
	h_hook_unregister_handler on_app_ending h_sta_stop
	h_hook_unregister_handler on_channel_changing h_sta_stop
	return 0
}
