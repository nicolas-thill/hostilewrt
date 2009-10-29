# aircrack

# .csv file format
# (fields separated by ',')
#
# 01. BSSID
# 02. First time seen
# 03. Last time seen
# 04. Channel
# 05. Speed
# 06. Privacy
# 07. Cipher
# 08. Authentication
# 09. Power
# 10. # beacons
# 11. # IV
# 12. LAN IP
# 13. ID-length
# 14. ESSID
# 15. KeyM

#
# @function
#  h_csv_get
# @description
#  get the line matching a specified AP
# @arguments
#  - file
#    a .csv file
#  - bssid
#    the BSSID of the requested AP
# @returns
#  the matching line (string) on stdout
# 
h_csv_get() {
	local F
	local B
	F=$1
	B=$2
	cat $F 2>/dev/null | tail -n +3 | grep "^$B,"
}

#
# @function
#  h_csv_get_network_iv_count
# @description
#  get the current IV count for the specified AP
# @arguments
#  - file
#    a .csv file
#  - bssid
#    the BSSID of the requested AP
# @returns
#  the number of IVs (string) or 0 on stdout
# 
h_csv_get_network_iv_count() {
	local F
	local B
	local v
	F=$1
	B=$2
	v=$(h_csv_get $F $B | awk -F\, '{ print $11; }')
	[ -z "$v" ] && v=0
	echo $v
}

#
# @function
#  h_csv_get_network_sta
# @description
#  get client stations for the specified bssid
# @arguments
#  - file
#    a .csv file
#  - bssid
#    the bssid of the requested AP
# @returns
#  client hw adresses (multi-line string) on stdout
# 
h_csv_get_network_sta() {
	local F
	local B
	F=$1
	B=$2
	cat $F 2>/dev/null | grep "^.*,.*,.*,.*,.*, $B" | awk -F\, '{ print $1; }'
}

# .kismet.csv file format
# (fields separated by ';')
#
# 01. Network
# 02. NetType
# 03. ESSID
# 04. BSSID
# 05. Info
# 06. Channel
# 07. Cloaked
# 08. Encryption
# 09. Decrypted
# 10. MaxRate
# 11. MaxSeenRate
# 12. Beacon
# 13. LLC
# 14. Data
# 15. Crypt
# 16. Weak
# 17. Total
# 18. Carrier
# 19. Encoding
# 20. FirstTime
# 21. LastTime
# 22. BestQuality
# 23. BestSignal
# 24. BestNoise
# 25. GPSMinLat
# 26. GPSMinLon
# 27. GPSMinAlt
# 28. GPSMinSpd
# 29. GPSMaxLat
# 30. GPSMaxLon
# 31. GPSMaxAlt
# 32. GPSMaxSpd
# 33. GPSBestLat
# 34. GPSBestLon
# 35. GPSBestAlt
# 36. DataSize
# 37. IPType
# 38. IP

#
# @function
#  h_kis_get
# @description
#  get interesting lines (network informations)
# @arguments
#  - file
#    a .kismet.csv file
# @returns
#  network informations (multi-line string) on stdout
#  format: see above
# 
h_kis_get() {
	local F
	F=$1
	cat $F 2>/dev/null | tail -n +2 | grep "^.*;infra"
}

#
# @function
#  h_kis_get_networks
# @description
#  get basic information for all networks
# @arguments
#  - file
#    a .kismet.csv file
# @returns
#  basic network informations (multi-line string) on stdout
#  format: signal;encryption;index
#  sorted by best signal first
# 
h_kis_get_networks() {
	local F
	F=$1
	h_kis_get $F | awk -F\; '{ print $22 "\;" $8 "\;" $1; }' | sort -n -r
}

#
# @function
#  h_kis_get_networks_by_enc
# @description
#  get index of networks matching the specified encryption 
# @arguments
#  - file
#    a .kismet.csv file
#  - encryption
#    the requested encryption (OPN, WEP or WPA)
# @returns
#  network index (multi-line string) on stdout
# 
h_kis_get_networks_by_enc() {
	local F
	local E
	F=$1
	E=$2
	h_kis_get_networks $F | grep "^.*;$E" | awk -F\; '{ print $3; }'
}

#
# @function
#  h_kis_get_essids
# @description
#  get all network ESSIDs 
# @arguments
#  - file
#    a .kismet.csv file
# @returns
#  network ESSID (multi-line string) on stdout
#  sorted, with dupe removed
# 
h_kis_get_essids() {
	local F
	F=$1
	h_kis_get $F | awk -F\; '{ print $3; }' | sort -u | grep -v "^$"
}

#
# @function
#  h_kis_get_network_bssid
# @description
#  get the BSSID of the specified network
# @arguments
#  - file
#    a .kismet.csv file
#  - index
#    the index of the requested network
# @returns
#  network BSSID (string) on stdout
# 
h_kis_get_network_bssid() {
	local F
	local N
	F=$1
	N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $4; }'
}

#
# @function
#  h_kis_get_network_channel
# @description
#  get the channel of the specified network
# @arguments
#  - file
#    a .kismet.csv file
#  - index
#    the index of the requested network
# @returns
#  network channel (string) on stdout
# 
h_kis_get_network_channel() {
	local F
	local N
	F=$1
	N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $6; }'
}

#
# @function
#  h_kis_get_network_essid
# @description
#  get the ESSID of the specified network
# @arguments
#  - file
#    a .kismet.csv file
#  - index
#    the index of the requested network
# @returns
#  network ESSID (string) on stdout
# 
h_kis_get_network_essid() {
	local F
	local N
	F=$1
	N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $3; }'
}

#
# @function
#  h_kis_get_network_max_rate
# @description
#  get the maximum rate of the specified network
# @arguments
#  - file
#    a .kismet.csv file
#  - index
#    the index of the requested network
# @returns
#  network maximum rate (string) on stdout
# 
h_kis_get_network_max_rate() {
	local F
	local N
	F=$1
	N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $10; }' | awk -F. '{ print $1; }'
}

h_check_aircrack_version() {
	if test `airodump-ng --help | grep Airodump-ng | cut -d ' ' -f 6 | cut -c 2-10` -lt 1513 ; 
	then 
		h_log 0 "You are using a release of aircrack-ng prior to r1513... this is probably not going to work"
	fi
}


h_auth_start() {
	$@ >/dev/null 2>&1 &
	H_AUTH_PID="$! $H_AUTH_PID"
	return 0
}

h_auth_stop() {
	local pid
	for pid in $H_AUTH_PID; do
		kill -TERM $pid 2>/dev/null
	done
	unset H_AUTH_PID
	return 0
}


h_capture() {
	h_exec airodump-ng $H_MON_IF $*
}

h_capture_start() {
	[ -z "$H_CAPTURE_PID" ] || return 1
	$@ >/dev/null 2>&1 &
	H_CAPTURE_PID=$!
	return 0
}

h_capture_stop() {
	[ -n "$H_CAPTURE_PID" ] || return 1
	kill -TERM $H_CAPTURE_PID 2>/dev/null
	unset H_CAPTURE_PID
	return 0
}


h_crack_start() {
	[ -z "$H_CRACK_PID" ] || return 1
	$@ >/dev/null 2>&1 &
	H_CRACK_PID=$!
	H_CRACK_TIME_STARTED=$(h_now)
	return 0
}

h_crack_stop() {
	[ -n "$H_CRACK_PID" ] || return 1
	kill -TERM $H_CRACK_PID 2>/dev/null
	unset H_CRACK_TIME_STARTED
	unset H_CRACK_PID
	return 0
}


h_replay_start() {
	[ -z "$H_REPLAY_PID" ] || return 1
	$@ >/dev/null 2>&1 &
	H_REPLAY_PID=$!
	return 0
}

h_replay_stop() {
	[ -n "$H_REPLAY_PID" ] || return 1
	kill -TERM $H_REPLAY_PID 2>/dev/null
	unset H_REPLAY_PID
	return 0
}
