#!/bin/bash

cd /home/ijl20/prologpf

ppc_pid=$(ps aux | grep ijl20/prologpf/ppc/ppc | grep -v grep | awk '{print $2}')
if [[ $ppc_pid != "" ]]
then
   kill -9 $ppc_pid
fi
/home/ijl20/prologpf/ppc/ppc >/tmp/ppc.log 2>/tmp/ppc.log2 &
exit
