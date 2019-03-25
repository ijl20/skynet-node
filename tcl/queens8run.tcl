#!/usr/bin/wish -f

set prog "queens8_cut_c"

set g_min  3
set g_max  30
set g_step 3

set l_min  3
set l_max  36
set l_step 3

source skynet.tcl

sky_connect [sky_hosts all closed]

for {set l $l_min} {$l <= $l_max} {set l [expr $l+$l_step]} {
    for {set g $g_min} {$g <= $g_max} {set g [expr $g+$g_step]} {
      sky_bfp [sky_hosts $g] $prog $l
      sky_wait
    }
}
sky_disconnect [sky_hosts all]
