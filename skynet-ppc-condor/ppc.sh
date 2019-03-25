#!/bin/bash
# file name: ijl20_test.sh

TIMETOWAIT="30"
echo $(hostname) $_CONDOR_SLOT "sleeping for $TIMETOWAIT seconds"
/bin/sleep $TIMETOWAIT
echo $(date +"%T") $(hostname) $_CONDOR_SLOT Job Completed | nc carrier.csi.cam.ac.uk 83

