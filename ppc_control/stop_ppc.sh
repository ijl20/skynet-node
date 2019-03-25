#!/bin/bash

# Usage: stop_ppc.sh [count]
# Will kill <count> number of ppc processes
#
# If count is not given, then it will default to 1, ppc launched in foreground, stdout and stderr to terminal
# If count IS given, then each ppc launched in background with stdout,stderr piped to /tmp

cd /home/ijl20/prologpf

ppc_count=$(ps aux | grep "ppc $HOSTNAME" | grep -v grep | wc -l)

# if no argument then default to kill all ppc processes
for ((i=1;i<=${1-99999};++i))
do
    # get the PID of the next ppc process
    ppc_pid=$(ps aux | grep "ppc $HOSTNAME" | grep -v grep | awk 'NR==1' | awk '{print $2}')

    # if we got a valid pid then kill that process
    if [[ $ppc_pid != "" ]]
    then
        proc_name=$(ps -f --pid "$ppc_pid" | awk 'NR==2' | awk '{ print substr($0, index($0,$8)) }')
        echo $i. Killing $ppc_pid \($proc_name\)
        kill -9 $ppc_pid
    else
        # no pid so just quietly exit
        break
    fi
done

exit 0
