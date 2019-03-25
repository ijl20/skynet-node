#!/usr/bin/ksh

cd ~/src/prolog/delphi/wamcc

ppc_pid=$(ps aux | grep ijl20/bin/ppc | grep -v grep | awk '{print $2}')
if [[ $ppc_pid != "" ]]
then
   kill -9 $ppc_pid
fi
~/bin/ppc >/tmp/ppc.log 2>/tmp/ppc.log2 &
exit
