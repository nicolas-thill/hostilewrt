# AP

H_AP_DNSMASQ_LEASE_F=$H_RUN_D/hostile-dnsmasq.leases
H_AP_DNSMASQ_PID_F=$H_RUN_D/hostile-dnsmasq.pid

h_ap_start() {
	local cmd
	h_log "starting: AP"
	h_log "using: $H_AP_IF/$H_AP_IP/$H_AP_NETMASK for AP"
	ifconfig $H_AP_IF down
	iwconfig $H_AP_IF essid "$H_AP_ESSID"
	ifconfig $H_AP_IF $H_AP_IP netmask $H_AP_NETMASK up
	cmd="dnsmasq -i $H_AP_IF -F $H_AP_DHCP_MIN,$H_AP_DHCP_MAX,$H_AP_DHCP_LEASE_TIME -l $H_AP_DNSMASQ_LEASE_F -x $H_AP_DNSMASQ_PID_F"
	h_log "running: $cmd"
	$cmd
	[ $? -eq 0 ] && {
		return 0
	}
	return 1
}

h_ap_stop() {
	local pid=$(cat $H_AP_DNSMASQ_PID_F 2>&1)
	h_log "stopping: AP"
	[ -n "$pid" ] && kill -TERM $pid >/dev/null 2>&1
	ifconfig $H_AP_IF down
}
