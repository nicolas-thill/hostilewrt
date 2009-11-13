# AP

H_AP_DNSMASQ_LEASE_F=$H_RUN_D/dnsmasq.leases
H_AP_DNSMASQ_PID_F=$H_RUN_D/dnsmasq.pid

h_ap_startup() {
	[ "$H_OP_MODE_ap" = "1" ] || return 0

	h_log 1 "AP: starting ($H_AP_IF/$H_AP_IP/$H_AP_NETMASK)"

	h_log 1 "AP: configuring wireless"
	h_run ifconfig $H_AP_IF down
	h_run iwconfig $H_AP_IF essid "$H_AP_ESSID"
	h_run ifconfig $H_AP_IF $H_AP_IP netmask $H_AP_NETMASK up

	h_log 1 "AP: starting DHCP/DNS server"
	h_run dnsmasq -i $H_AP_IF -F $H_AP_DHCP_MIN,$H_AP_DHCP_MAX,$H_AP_DHCP_LEASE_TIME -l $H_AP_DNSMASQ_LEASE_F -x $H_AP_DNSMASQ_PID_F

	h_hook_register_handler on_app_ending h_ap_cleanup

	return 0
}

h_ap_cleanup() {
	local pid

	h_log 1 "AP: stopping"

	pid=$(cat $H_AP_DNSMASQ_PID_F 2>&1)
	if [ -n "$pid" ]; then
		h_log 1 "AP: stopping DHCP/DNS server"
		kill -TERM $pid >/dev/null 2>&1
		sleep 1
		echo "" > $H_AP_DNSMASQ_PID_F
		h_run ifconfig $H_AP_IF down
	fi

	h_hook_unregister_handler on_app_ending h_ap_cleanup

	return 0
}

h_hook_register_handler on_app_started h_ap_startup
