#!/bin/bash
for ((i=1;i<=${1-1};++i))
do
  ( echo $i );
done
exit
