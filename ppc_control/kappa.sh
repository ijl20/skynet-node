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
# in a message to the ppc "skynet split Orc W"                       #
# where Orc is the number of seconds left in this particular job  #

function interrupted {
	remaining_work=$((work_required-work_done))
    # only agree to split if more than 1 second of work remaining
    if (( remaining_work > 1 ))
    then
        printf "\nskynet split $remaining_work $work_done\n"
        split=1
    else
        printf "\nskynet nosplit (ppc is completing anyway)\n"
    fi
}

trap interrupted SIGHUP
#                                                                  #
####################################################################

####################################################################
# DEFINE work calculation function (for bc command)                #
# 2015-05-29: version 2, integrating original formula
# 2015-05-26: version 1, using .007 + 2*x -2.5 x^2 + 5 * x^5 as
#             point value, with average between points (wrong...)
WORK_FN=$(cat <<EOF
scale = 4;

define w_point(x) {
 return (0.007*x + x^2 - 5 / 6 *  x^3 + 5 / 6 * x^6);
}

define w_ppc(g,n,w) {
 return (w_point((n+1)/g)-w_point(n/g)) * w;
}

EOF
)

###########################################################
# SEND 'LOADED' STATUS TO PPC (console will turn BLUE)    #
###########################################################

echo skynet loaded $0 $1

###########################################################
# loop until 'exit' command (or SIGKILL) received
###########################################################

while :
do

# not interrupted yet - this will be set to 1 in SIGINT handler
split=0

# READ 'RUN' COMMAND FROM PPC
# COMMAND = 'run'
# PROC = procedure name to run (currently ignored)
# O = Oracle (information to identify processing required
#     In a real Kappa program this will be a path into the search tree
#     but in this kappa.sh simulation is is actually the total work in seconds
# G = number of path processors in this group
# N = id of this path processor 0..G-1
# e.g. will receive "run kappa 450 12 3" = run procedure "kappa", we are pp 3 out of 12, oracle=450
# note that this SIMLUATION of a kappa program has the Oracle
read KAPPA_COMMAND PROC O G N

if [[ "$KAPPA_COMMAND" == "exit" ]]
then
    exit 0
fi

# have this version of kappa.sh default to 450 seconds of work

if [[ $O == "init" ]]
then
    O=${1-450}
fi

###########################################################
# SEND 'RUNNING' STATUS TO PPC (console will turn GREEN)  #
###########################################################

echo skynet running $PROC $O $G $N

# Now this processor has to calculate how much within that job will be done here

# the x^5 polynomial is a SIMULATION of the  distribution of work
# between G path processors, matching actual results from PrologPF
# e.g. "run 450 12 3" will allocate 14.437 seconds of work to processor #3 of 12.

# using 'bc' command to do the floating point:
work_required_fp=$(echo "$WORK_FN" "w_ppc($G,$N,$O)" | bc)

work_required=$(printf "%.0f" $work_required_fp)

work_done=0

###########################################################
#general message to ppc, will be forwarded to skynet console
###########################################################

#echo $G $N $O work calculated was $work_required

#debug
#exit 0

# note careful here... bash only deals with integers

while (( split == 0 && work_done <= work_required ))
do
	sleep 1
	(( work_done ++ ))
done

###########################################################
# SEND 'COMPLETED' STATUS TO PPC (console will turn blue) #
# unless a split occurred (so split message already sent) #
###########################################################

if (( split == 0 ))
then
    echo skynet completed $PROC $O $G $N $work_required
fi

#end of outermost 'while :' loop
# will continue looping until 'exit' command or SIGKILL received
done
