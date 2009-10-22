# h_platform
# Hardware Platform / OS specific

H_PLATFORMS="fonera-1,fonera-2,generic-pc"

H_OS=$(uname -s)
H_MACHINE=$(uname -m)

if [ "$H_OS" = "Linux" ]; then
  if echo "$H_MACHINE" | grep -q "i\i?86" ; then
    H_PLATFORM="generic-pc"
  else
    if cat /proc/cpuinfo | grep -q "Atheros AR2315" ; then
      if [ -d /sys/bus/usb ]; then
        H_PLATFORM="fonera-2"
      else
        H_PLATFORM="fonera-1"
      fi
    fi
  fi
fi
