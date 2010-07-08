#!/bin/sh

#
# Copyright (C) 2009-2010 /tmp/lap <contact@tmplab.org>
#
# This is free software, licensed under the Exception General Public 
# License v2. See /COPYING for more information.
#

H_RESOLV_CONF_F="/etc/resolv.conf"

case "$1" in
	deconfig)
		ifconfig $interface 0.0.0.0
		;;

	renew|bound)
		ifconfig $interface $ip ${subnet:+netmask }${subnet} ${broadcast:+broadcast }${broadcast}

		if [ -n "$router" ] ; then
			while route del default gw 0.0.0.0 dev $interface; do
				:
			done
			for i in $router ; do
				route add default gw $i dev $interface
			done
		fi

		echo -n > $H_RESOLV_CONF_F
		if [ -n "$domain" ]; then
			echo "search $domain" >> $H_RESOLV_CONF_F
		fi
		for i in $dns ; do
			echo "nameserver $i" >> $H_RESOLV_CONF_F
		done
		;;
esac

exit 0
