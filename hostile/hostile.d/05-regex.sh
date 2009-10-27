# h_regex
# (extended) regular expression helpers

#
# @function
#  h_regex_match
# @description
#  match a value against an extended regex pattern using grep
# @arguments
#  - value
#    the value to match against supplied pattern
#  - pattern
#    the pattern to use for matching
# @returns
#  TRUE if the value matches the pattern, FALSE otherwise
# @examples
#  h_regex_match "DeadBox-FAB9" "^DeadBox-[0-9a-zA-Z]+"
#
h_regex_match() {
	local value
	local pattern
	value="$1"
	pattern="$2"
	echo "$value" | grep -E -q "$pattern"
}

#
# @function
#  h_regex_loop_match
# @description
#  match a value against a serie of extended regex patterns read from stdin
# @arguments
#  - value
#    the value to match against patterns, it can be empty if callback is 
#    provided
#  - callback
#    an optional callback function that will be called to match the value
#    against each pattern. if it is not provided, the above h_regex_match
#    function is used
# @returns
#  TRUE if a match is found, FALSE otherwise
# @examples
#  cat /tmp/ssid-patterns.txt | h_regex_loop_match "DeadBox-FAB9"
#
h_regex_loop_match() {
	local value
	local callback
	local pattern
	value="$1"
	callback="$2"
	[ -n "$callback" ] || callback="h_regex_match"
	while [ true ]; do
		IFS="" read pattern
		[ -n "$pattern" ] || break
		$callback "$value" "$pattern" && return 0
	done
	return 1
}
