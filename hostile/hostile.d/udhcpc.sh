#!/bin/sh

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
