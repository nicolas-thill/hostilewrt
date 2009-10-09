#!/bin/sh
cp hostile /etc/init.d/
chmod a+rx /etc/init.d/hostile
cd /etc/rc.d/
ln -s ../init.d/hostile S48hostile
cd -
