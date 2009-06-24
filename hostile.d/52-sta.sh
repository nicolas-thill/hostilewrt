# STA

h_sta_start() {
	local bssid=$1
	local channel=$2
	local essid=$3
	local end=$4
	local key=$5
	ifconfig $H_STA_IF down
	iwconfig $H_STA_IF ap "$bssid"
	iwconfig $H_STA_IF essid "$essid"
	iwconfig $H_STA_IF enc "$enc"
	iwconfig $H_STA_IF key "$key"
	udhcpc -i $H_STA_IF -p $H_STA_PID_F -f >/dev/null 2>&1 &
	H_STA_DHCPC=$!
}
