# h_utils
# misc utility helper functions

h_get_last_file() {
	echo $(ls -1 $* | tail -n 1)
}

h_get_sane_fname() {
	local F
	F=$1
	echo $F | tr ':/' '__'
}
