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

h_csv_get() {
	local F
	local B
	F=$1
	B=$2
	cat $F 2>/dev/null | tail -n +3 | grep "^$B,"
}

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

h_kis_get() {
	local F
	F=$1
	cat $F 2>/dev/null | tail -n +2 | grep "^.*;infra"
}

h_kis_get_networks() {
	local F
	F=$1
	h_kis_get $F | awk -F\; '{ print $22 "\;" $8 "\;" $1; }' | sort -n -r
}

h_kis_get_networks_by_enc() {
	local F
	local E
	F=$1
	E=$2
	h_kis_get_networks $F | grep "^.*;$E" | awk -F\; '{ print $3; }'
}

h_kis_get_network_bssid() {
	local F
	local N
	F=$1
	N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $4; }'
}

h_kis_get_network_channel() {
	local F
	local N
	F=$1
	N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $6; }'
}

h_kis_get_network_essid() {
	local F
	local N
	F=$1
	N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $3; }'
}

h_kis_get_network_max_rate() {
	local F
	local N
	F=$1
	N=$2
	h_kis_get $F | grep "^$N;" | awk -F\; '{ print $10; }' | awk -F. '{ print $1; }'
}

