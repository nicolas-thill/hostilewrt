# h_platform
# Hardware Platform / OS specific

h_platform_detect() {
	local cpu

	H_MACHINE=$(uname -m)
	H_OS=$(uname -s)
	case $H_OS in
	  *Linux*)
		cpu=$(cat /proc/cpuinfo |grep "cpu model" | cut -d: -f2)
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
				  *BCM4710*)
					if [ -d /sys/bus/ide ]; then
						H_PLATFORM="wl-hdd"
					fi
					;;
				esac
				;;
			esac
			;;
		esac
		;;
	esac

	[ -n "$H_PLATFORM" ] || H_PLATFORM="unknown"
}

h_hook_register_handler on_app_starting h_platform_detect
