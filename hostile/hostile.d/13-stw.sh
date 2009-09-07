#!/bin/sh
# WEP Dict size
# 001 : 5k == 1mn @ 7 tests per seconds

# ------------------------- INITIALISATION
#set -x
if [ -n "$H_LIB_D" ]
then
    export H_SSID_D=$H_LIB_D/ssid-to-wordlist
    export H_DICT_D=$H_LIB_D/dict
else
    export H_SSID_D=./ssid-to-wordlist
    export H_DICT_D=./dict
fi    

# ------------------------- FUNCTIONS
stw_ssid_to_regexp()
{
# $1 : country code
if [ \! -n "$1" ]
then
    echo "ERROR: No parameter given, need only one: country code (such as 'fr')"
    return
fi
local isfirst
isfirst=1
cat $H_SSID_D/"$1".ssid | while read a
do
    if [ $isfirst -eq 1 ]
    then
	echo -n "$a"
	isfirst=0
    else
	echo -n "|$a"
    fi
done
}
#echo `stw_ssid_to_regexp $1`

stw_list()
{
# No argument
#echo "$H_SSID_D/*.ssid" $H_SSID_D/*.ssid # DEBUG
ls -1 $H_SSID_D/*.ssid | while read a; do basename $a; done | cut -d. -f1
}
#stw_list

stw_get_matches()
{
# $1 : country code
# $2 : file to check
# Returns: count of 
local regexp=`stw_ssid_to_regexp $1`
grep -Ec "$regexp" $2
}
#stw_get_matches $1 $2

stw_country_get()
{
# $1 : file to check
if [ \! -n "$1" ]
then
    echo "ERROR: No parameter given, need only one: file with ssids to identify"
    return
fi
export filetocheck=$1
export top=0
export topcountry=""
for country in `stw_list`
do
    #echo $country # DEBUG
    export lcount=`stw_get_matches $country $filetocheck`
    #echo "RESULT IS=$country $lcount" # DEBUG
    if test $lcount -gt $top
    then
	export topcountry=$country
	top=$lcount
	#echo "NEW CHALLENGER IS=$top $topcountry" # DEBUG
    fi
done
#echo "WINNER IS=$top $topcountry" # DEBUG
echo "$topcountry"
}
stw_country_get "$1"
