#!/bin/bash
#file: kappa.sh

################################################################################
########  Script to simulate a 'kappa' program capable of work-splitting  ######
################################################################################

# Message sequence (-> = TO ppc/skynet, <- = FROM ppc/skynet)
# (... ppc connects to skynet server) (web status YELLOW)
# (... this program is spawned)
# -> skynet loaded                    (web status BLUE) 
# <- run G N WORK
# -> skynet started                   (web status GREEN)
# (...program executes work)
# -> skynet completed                 (web status BLUE)
#
# or if ppc receives CHILD_INTERRUPT
# <- SIGCHILD
# -> skynet split WORK                (web status FLASH WHITE)

####################################################################
# DEFINE SIGCHILD INTERRUPT HANDLER                                #
# if interrupted, process will communicate back work remaining     #
# in a message to the ppc "interrupted WORK"                       #
# where WORK is the number of seconds left in this particular job  #

function interrupted {
	remaining_work=$((loop_limit-loop))
	echo skynet split $loop $remaining_work
	exit 0 
}

trap interrupted SIGINT
#                                                                  #
####################################################################

####################################################################
# DEFINE work calculation function (for bc command)                #

WORK_FN=$(cat <<EOF
scale = 3;

define w_point(x) {
 return (0.007 + 2*x - 2.5 *  x^2 + 5 * x^5);
}

define w_ppc(g,n,w) {
 return (w_point(n/g)+w_point((n+1)/g)) / 2 * w / g
}

EOF
)

# SEND 'LOADED' STATUS TO PPC (console will turn BLUE)

echo skynet loaded $0

# READ 'RUN' COMMAND FROM PPC
# RUN_COMMAND = 'run'
# G = number of path processors in this group
# N = id of this path processor 0..G-1
# W = (for this simulation) total amount of work for whole group (so this proc will calculate sub-work)
# e.g. will receive "run 12 3 450" = we are pp 3 out of 12, with 450 seconds of work for group
read RUN_COMMAND G N W

# SEND 'RUNNING' STATUS TO PPC (console will turn GREEN)
echo skynet running $G $N $W

# Now this processor has to calculate how much within that job will be done here

# the x^5 polynomial is a SIMULATION of the  distribution of work
# between G path processors, matching actual results from PrologPF
# e.g. "run 12 3 450" will allocate 14.437 seconds of work to processor #3 of 12.

# using 'bc' command to do the floating point:
local_work=$(echo "$WORK_FN" "w_ppc($G,$N,$W)" | bc)

loop_limit=$(printf "%.0f" $local_work)

loop=0

#general message to ppc, will be forwarded to skynet console
echo $G $N $W work calculated was $loop_limit

#debug
#exit 0

# note careful here... bash only deals with integers

while (( loop <= loop_limit ))
do
	sleep 1
	(( loop ++ ))
done

# SEND 'COMPLETED' STATUS TO PPC (console will turn blue)
echo skynet completed $G $N $W
