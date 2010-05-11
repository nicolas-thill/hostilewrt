# h_platform
# Hardware Platform / OS specific

h_platform_detect() {
	local cpu

	H_MACHINE=$(uname -m)
	H_OS=$(uname -s)
	case $H_OS in
	  *Linux*)
		cpu=$(cat /proc/cpuinfo |grep "system type" | cut -d: -f2)
		case $H_MACHINE in
		  i?86)
			H_PLATFORM="generic-pc"
			;;
		  mips)
			case $cpu in
			  *Atheros*)
				case $cpu in
				  *AR2315*)
					if [ -d /sys/bus/usb ]; then
						H_PLATFORM="fon2202"
					else
						H_PLATFORM="fon2100"
					fi
					;;
				esac
				;;
			  *Broadcom*)
				case $cpu in
				  *BCM47XX*)
					if [ -d /sys/bus/ide ]; then
						H_PLATFORM="wl-hdd"
					elif [ -d /sys/bus/usb ]; then
						H_PLATFORM="wl-500g"
					fi
					;;
				esac
				;;
			esac
			;;
		esac
		;;
	esac

	if [ -n "$H_PLATFORM" ]; then
		h_log 1 "detected platform: '$H_PLATFORM'"
	else
		h_log 1 "unable to guess current platform, assuming 'unknown'"
		H_PLATFORM="unknown"
	fi

	return 0
}

h_platform_detect_small_storage() {
	local avail
	
	avail=$(df -m $H_RUN_D | tail -n +2 | awk '{ print $4; }')
	if [ -z "$avail" ]; then
		h_log 1 "unable to guess available storage space"
		return
	fi
	if [ $avail -lt 100 ]; then
		H_SMALL_STORAGE=1
	fi
}

h_hook_register_handler on_app_starting h_platform_detect
h_hook_register_handler on_app_starting h_platform_detect_small_storage
