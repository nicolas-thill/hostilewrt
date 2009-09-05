# h_led

H_LED_SUCCESS=gpio4
H_LED_WIP=gpio7

h_led_on() {
	local led
	led=$1
	echo "none" > /sys/class/leds/$led/trigger
	echo 255 > /sys/class/leds/$led/brightness
}

h_led_blink() {
	local led
	local delay
	led=$1
	delay=$2
	echo "timer" > /sys/class/leds/$led/trigger
	echo $delay > /sys/class/leds/$led/delay_on
	echo $delay > /sys/class/leds/$led/delay_off
}

h_led_off() {
	local led
	led=$1
	echo "none" > /sys/class/leds/$led/trigger
	echo 0 > /sys/class/leds/$led/brightness
}

h_leds_on_app_started() {
	h_led_off $H_LED_SUCCESS
	h_led_blink $H_LED_WIP 500
}

h_leds_on_app_ended() {
	h_led_off $H_LED_SUCCESS
	h_led_off $H_LED_WIP
}

h_leds_on_wep_attack_started() {
	h_led_blink $H_LED_WIP 500
}

h_leds_on_wep_attack_working() {
	h_led_blink $H_LED_WIP 100
}

h_leds_on_wep_key_found() {
	h_led_on $H_LED_SUCCESS
}

h_leds_wrt () {
	h_hook_register_handler on_app_started h_leds_on_app_started
	h_hook_register_handler on_app_ended h_leds_on_app_ended
	h_hook_register_handler on_wep_attack_started h_leds_on_wep_attack_started
	h_hook_register_handler on_wep_attack_working h_leds_on_wep_attack_working
	h_hook_register_handler on_wep_key_found h_leds_on_wep_key_found
}

h_leds_linux () {
}

[ "$OSTYPE" == "linux-gnu" ] && h_leds_linux || h_leds_wrt
