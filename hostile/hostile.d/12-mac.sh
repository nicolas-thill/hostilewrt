# mac

#
# Copyright (C) 2009-2010 /tmp/lap <contact@tmplab.org>
#
# This is free software, licensed under the Exception General Public 
# License v2. See /COPYING for more information.
#

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
