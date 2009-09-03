#!/bin/sh
# WEP Dict size
# 001 : 5k == 1mn @ 7 tests per seconds

#set -x

stw_ssid_to_regexp()
{
# $1 : country code
local isfirst
isfirst=1
cat "$1".ssid | while read a
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

#echo `stw_ssid_to_regexp fr`

stw_list()
{
# No argument
ls -1 *.ssid | cut -d. -f1
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

stw_get()
{
# $1 : file to check
export filetocheck=$1
export top=0
export topcountry=""
for country in `stw_list`
do
echo $country
export lcount=`stw_get_matches $country $filetocheck`
echo "RESULT IS=$country $lcount"
if test $lcount -gt $top
then
    export topcountry=$country
    top=$lcount
    echo "NEW CHALLENGER IS=$top $topcountry"
fi
done
echo "WINNER IS=$top $topcountry"
}

stw_get $1
