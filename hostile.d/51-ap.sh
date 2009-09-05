# AP

H_AP_DNSMASQ_LEASE_F=$H_RUN_D/hostile-dnsmasq.leases
H_AP_DNSMASQ_PID_F=$H_RUN_D/hostile-dnsmasq.pid

h_ap_start() {
	local cmd
	[ -n "$H_OP_MODE_ap" ] \
		|| return
	h_log "starting: AP"
	h_log "using: $H_AP_IF/$H_AP_IP/$H_AP_NETMASK for AP"
	ifconfig $H_AP_IF down
	iwconfig $H_AP_IF essid "$H_AP_ESSID"
	ifconfig $H_AP_IF $H_AP_IP netmask $H_AP_NETMASK up
	cmd="dnsmasq -i $H_AP_IF -F $H_AP_DHCP_MIN,$H_AP_DHCP_MAX,$H_AP_DHCP_LEASE_TIME -l $H_AP_DNSMASQ_LEASE_F -x $H_AP_DNSMASQ_PID_F"
	h_log "running: $cmd"
	$cmd
	h_hook_register_handler on_app_ending h_ap_stop
	return 0
}

h_ap_stop() {
	local pid
	h_log "stopping: AP"
	pid=$(cat $H_AP_DNSMASQ_PID_F 2>&1)
	if [ -n "$pid" ]; then
		kill -TERM $pid >/dev/null 2>&1
		sleep 1
		echo "" > $H_AP_DNSMASQ_PID_F
		ifconfig $H_AP_IF down
	fi
	h_hook_unregister_handler on_app_ending h_ap_stop
	return 0
}

h_hook_register_handler on_app_started h_ap_start
