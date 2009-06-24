# STA

H_STA_UDHCPC_PID_F=$H_RUN_D/hostile-udhcpc.pid
H_STA_UDHCPC_SCRIPT_F=/dev/null

h_sta_start() {
	local bssid=$1
	local channel=$2
	local essid=$3
	local enc=$4
	local key=$5
	ifconfig $H_STA_IF down
	iwconfig $H_STA_IF ap "$bssid"
	iwconfig $H_STA_IF essid "$essid"
	iwconfig $H_STA_IF enc "$enc"
	iwconfig $H_STA_IF key "$key"
	udhcpc -f -i $H_STA_IF -p $H_STA_UDHCPC_PID_F -s $H_STA_UDHCPC_SCRIPT_F >/dev/null 2>&1 &
}
