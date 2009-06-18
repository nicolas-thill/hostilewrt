# h_led

H_LED_SUCCESS=gpio4
H_LED_WIP=gpio7

h_led_on() {
	local led=$1
	echo "none" > /sys/class/leds/$led/trigger
	echo 255 > /sys/class/leds/$led/brightness
}

h_led_blink() {
	local led=$1
	local delay=$2
	echo "timer" > /sys/class/leds/$led/trigger
	echo $delay > /sys/class/leds/$led/delay_on
	echo $delay > /sys/class/leds/$led/delay_off
}

h_led_off() {
	local led=$1
	echo "none" > /sys/class/leds/$led/trigger
	echo 0 > /sys/class/leds/$led/brightness
}
