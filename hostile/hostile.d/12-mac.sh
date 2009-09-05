# h_mac

h_mac_get() {
	local IF
	IF=$1
	macchanger --show $IF | sed -e 's,\(.*\) \([0-9a-f\]\+:[0-9a-f]\+:[0-9a-f]\+:[0-9a-f]\+:[0-9a-f]\+:[0-9a-f]\+\) \(.*\),\2,' 2>/dev/null \
		|| h_error "can't get '$IF' mac address"
}

h_mac_set() {
	local IF
	local MAC
	IF=$1
	MAC=$2
	local opt
	case $MAC in
		auto)
			opt="-a -e"
			;;
		*)
			opt="-m $MAC"
	esac
	ifconfig $IF down
	macchanger $opt $IF >/dev/null 2>&1 \
		|| h_error "can't set '$IF' mac address to '$MAC'"
}
