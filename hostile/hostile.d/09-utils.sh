# utils | misc utility helper functions

#
# Copyright (C) 2009-2010 /tmp/lap <contact@tmplab.org>
#
# This is free software, licensed under the Exception General Public 
# License v2. See /COPYING for more information.
#

h_get_last_file() {
	echo $(ls -1 $* | tail -n 1)
}

h_get_sane_fname() {
	local F
	F=$1
	echo $F | tr ':/' '__'
}
