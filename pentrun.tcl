#!/usr/bin/wish -f

source skynet.tcl

sky_connect [sky_hosts all closed]

for {set g 39} {$g > 0} {set g [expr $g-3]} {
    for {set l 5} {$l < 11} {set l [expr $l+5]} {
      sky_bfp [sky_hosts $g] pentbook_cut_c $l
      sky_wait
    }
}
sky_disconnect [sky_hosts all]
