#!/bin/bash

# Usage: start_ppc.sh [count]
# Will launch <count> number of ppc processes, each given args $HOSTNAME and an number 1..count
# E.g. if count is 4 then
# ppc $HOSTNAME 1
# through to
# ppc $HOSTNAME 4
#
# If count is not given, then it will default to 1, ppc launched in foreground, stdout and stderr to terminal
# If count IS given, then each ppc launched in background with stdout,stderr piped to /tmp

#cd /home/ijl20/prologpf

for ((i=1;i<=${1-1};++i))
do
    (
        ppc_pid=$(ps aux | grep "ppc $(hostname) $_CONDOR_SLOT"$ | grep -v grep | awk '{print $2}')

        if [[ $ppc_pid != "" ]]
        then
            echo killing $ppc_pid \(ppc $(hostname) $_CONDOR_SLOT\)
            kill -9 $ppc_pid
        fi
        if [[ $1 ]]
        then
            ppc $(hostname) $_CONDOR_SLOT >/tmp/ppc_$_CONDOR_SLOT.log 2>/tmp/ppc_$_CONDOR_SLOT.log2 &
        else
            ppc $(hostname) $_CONDOR_SLOT
        fi
    );
done
exit
