# h_hook

# existing hooks
# - on_app_starting() / on_app_started()
# - on_app_ending() / on_app_ended()

h_hook_register_handlers() {
	local hook=$1
	shift
	local handlers="$*"
	local hook_var="H_HOOK_$hook"
	eval "handlers_old=\"\${$hook_var}\""
	eval "$hook_var=\"$handlers_old $handlers\""
}

h_hook_call_handlers() {
	local hook=$1
	shift
	local args="$*"
	local hook_var="H_HOOK_$hook"
	eval "handlers=\"\${$hook_var}\""
	for handler in $handlers; do
		$handler $args || return
	done
}
