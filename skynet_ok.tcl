
# SKYNET tcl procedures

# globals:
#
#    tk_strictMotif: set to 1 in proc sky_init for Motif tk behaviour
#
#    frame_count: number of vertical frames in "Skynet" window
#    current_frame: index of current "Skynet" window frame 0..frame_count-1
#
#    sky_hostsock:  array $host -> $sock
#    sky_sockhost:  array $sock -> $host
#
#    sky_hoststatus: array $host -> status {shutdown, connected, 
#                                            running, closed, nok}
#  
#  Globals for "status" window: 
#    sky_available sky_connected sky_running sky_oracles sky_bf_time
#    sky_solutions sky_cpu_time sky_comms_time sky_total_time
#    sky_completed sky_progname sky_limit
#    sky_g: G, the number of processors selected for this run
#
#    sky_exitted: the number of processes exitted
#
#    sky_end_run: trigger variable for proc sky_wait (set when
#                   sky_running = 0)
#
#    bfp_one_solution: flag set to 1 by sky_bfp_one to kill runners after
#                      first completion with solution
#
##########################################################################
#                sky_init                                                #
##########################################################################

proc sky_init {} {
  global tk_strictMotif
  global current_frame frame_count
  global sky_available sky_connected sky_running sky_oracles sky_bf_time
  global sky_solutions sky_cpu_time sky_comms_time sky_total_time
  global sky_completed sky_progname sky_limit sky_exitted
  global sky_g
  global sky_started
  global sky_end_run

  global bfp_one_solution

  set tk_strictMotif 1

  set sky_progname ""
  set sky_available  0
  set sky_connected  0 
  set sky_running    0 
  set sky_limit      0
  set sky_oracles    0 
  set sky_bf_time    0 
  set sky_solutions  0
  set sky_completed  0 
  set sky_cpu_time   0 
  set sky_comms_time 0 
  set sky_total_time 0 
  set sky_g          0
  set sky_exitted    0

  set bfp_one_solution 0
  wm title . "Skynet"
  wm geometry . 350x400+20+40

  set current_frame 0
  set frame_count 4
  for {set i 0} {$i < $frame_count} {incr i} {
    frame .frame$i -width 90
    pack .frame$i -side left -fill y
    }
  
  toplevel .incoming
  wm title .incoming "Incoming"
  wm geometry .incoming 600x360+550+440
  text .incoming.text -bd 2 -yscrollcommand ".incoming.scroll set"
  scrollbar .incoming.scroll -command ".incoming.text yview"
  pack .incoming.scroll -side right -fill y
  pack .incoming.text -side left

  toplevel .solutions
  wm title .solutions "Solutions"
  wm geometry .solutions 600x360+615+40
  text .solutions.text -bd 2 -yscrollcommand ".solutions.scroll set"
  scrollbar .solutions.scroll -command ".solutions.text yview"
  pack .solutions.scroll -side right -fill y
  pack .solutions.text -side left

  toplevel .status
  wm title .status "Status"
  wm geometry .status 220x300+380+40
  label .status.progname   -text "Progname:"
  label .status.available  -text "Available:\t 0"
  label .status.connected  -text "Connected:\t 0"
  label .status.running    -text "Running:\t 0"
  label .status.completed  -text "Completed:\t 0"
  label .status.limit      -text "Limit:\t 0"
  label .status.oracles    -text "Oracles:\t 0"
  label .status.bf_time    -text "BFtime:\t 0"
  label .status.solutions  -text "Solutions:\t 0"  
  label .status.cpu_time   -text "CPU time:\t 0"
  label .status.comms_time -text "Comms time:\t 0"
  label .status.total_time -text "Total runtime:\t 0"
  label .status.g          -text "G:\t 0"
  pack .status.progname -anchor w
  pack .status.available .status.connected .status.running -anchor w
  pack .status.completed -anchor w
  pack .status.oracles .status.cpu_time .status.comms_time -anchor w
  pack .status.bf_time .status.solutions  -anchor w
  pack .status.total_time .status.limit .status.g -anchor w

  return ""
}

proc incoming_clear {} {
  .incoming.text delete 1.0 end
}

proc solutions_clear {} {
  .solutions.text delete 1.0 end
}

##########################################################################
#                sky_exit {}                                             #
##########################################################################

proc sky_exit {} {
  sky_disconnect [sky_all]
  exit
}

##########################################################################
#                sky_add {host_list}                                     #
##########################################################################

proc sky_add host_list {
  global current_frame frame_count sky_hoststatus
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i]
    set sky_hoststatus($host) closed
    status_incr available
    button .$host -text $host -background grey -command "sky_connect $host"
    pack configure .$host -in .frame$current_frame -fill x
    incr current_frame
    if {$current_frame == $frame_count} {set current_frame 0} 
  }
}

##########################################################################
#                sky_connect {host}                                       #
##########################################################################

proc sky_connect host_list {
  global sky_hostsock sky_sockhost sky_hoststatus
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i] 
    update
    if {$sky_hoststatus($host) == "closed"} {
      set connect_bad [catch {set sock [socket -async $host.cl.cam.ac.uk 6173]}]
      if {$connect_bad} {
        set sky_hoststatus($host) shutdown
        .$host configure -background red
      } else {      
        set sky_hostsock($host) $sock 
        set sky_sockhost($sock) $host
        set read_sock_args [list $sock $host]
        fileevent $sock readable "read_sock $read_sock_args"
      }
    }
  }
}

proc ok_sky_connect host {
  global sky_hoststatus
  set sky_hoststatus($host) connected
  status_incr connected
  .$host configure -background yellow -command "sky_disconnect $host"
}

##########################################################################
#                sky_disconnect {host_list}                              #
##########################################################################

proc sky_disconnect host_list {
  global sky_hostsock sky_sockhost sky_hoststatus
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i] 
    set sock $sky_hostsock($host)
    puts $sock "close"
    set sky_hoststatus($host) closed
    status_decr connected
    .$host configure -background grey -command "sky_connect $host"
    unset sky_hostsock($host)
    unset sky_sockhost($sock)
    fileevent $sock readable ""
    close $sock
  }
}

##########################################################################
#                sky_startup {host_list}                                #
##########################################################################

proc sky_startup host_list {
  global sky_hostsock sky_sockhost sky_hoststatus
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i] 
    sky_connect $host
    sky_shutdown $host
    exec start_host.ksh $host &
    set sky_hoststatus($host) shutdown
    .$host configure -background pink -command "sky_connect $host"
  }
} 
 
##########################################################################
#                sky_shutdown {host_list}                                #
##########################################################################

proc sky_shutdown host_list {
  global sky_hostsock sky_sockhost sky_hoststatus
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i] 
    set bad_sock [catch {set sock $sky_hostsock($host)}]
    if {$bad_sock} {
    } else {
      puts $sock "shutdown"
      set sky_hoststatus($host) shutdown
      .$host configure -background red
      unset sky_hostsock($host)
      unset sky_sockhost($sock)
      fileevent $sock readable ""
      close $sock
    }
  }
} 
 
proc shutdown_remove host {
  global sky_hoststatus
  destroy .$host
  unset sky_hoststatus($host)
  status_decr available
}

##########################################################################
#                sky_kill {host_list}                                    #
##########################################################################

proc sky_kill host_list {
  global sky_hostsock sky_hoststatus
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i] 
    set sock $sky_hostsock($host)
    puts $sock "kill_child"
    flush $sock
  }
} 

##########################################################################
#                sky_wait {}                                             #
##########################################################################

proc sky_wait {} {
  global sky_end_run sky_running

#  if {$sky_running != 0} {
    tkwait variable sky_end_run

    puts "[status_read progname] [status_read g] [status_read completed] [status_read limit] \
          [status_read oracles] [status_read solutions] [status_read bf_time] \
          [status_read cpu_time]"
#  }
}

##########################################################################
#                read_sock {sock host}                                   #
##########################################################################

proc read_sock {sock host} {
  set sock_data [gets $sock]
  if {$sock_data == ""} { 
    sky_disconnect $host
    .incoming.text insert end "\n<$host>disconnected"
    .incoming.text see end    
  } else {
  .incoming.text insert end "\n<$host>$sock_data"
  .incoming.text see end
  scan_stream $host $sock_data
  }
}

##########################################################################
#                sky_send {host msg}                                     #
##########################################################################

proc sky_send {host_list msg} {
  global sky_hostsock
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i] 
    set sock $sky_hostsock($host)
    puts $sock $msg
    flush $sock
  }
}

##########################################################################
#                sky_all {}                                              #
##########################################################################

proc sky_all {} {
  global sky_hostsock
  return [array names sky_hostsock]
}

##########################################################################
#                sky_hosts {G status}                                    #
##########################################################################

proc sky_hosts {{G all} {status "connected"}} {
  global sky_hoststatus 
  set host_list [array names sky_hoststatus]
  set host_count [llength $host_list]
  set selected_hosts {}
  set i 0
  set G_count 0
  if {$G == "all"} { 
    set G_max $host_count
  } else {
    set G_max $G
  }
  while {($i < $host_count) && ($G_count < $G_max)} {
    set host [lindex $host_list $i]
    if {$sky_hoststatus($host) == $status} {
      lappend selected_hosts $host
      incr G_count
    }
    incr i
  }
  if {($G != "all") && ($G != $G_count)} {
      return {}
  } else {
      return $selected_hosts
  }
}

##########################################################################
#                scan_stream sock_data                                   #
##########################################################################

proc scan_stream {host sock_data} {
  if [string match "ok sky_connect*" $sock_data] {
      ok_sky_connect $host
  } elseif [string match "delphi bfp started*" $sock_data] {
      delphi_started $host
  } elseif [string match "delphi bfp oracles*" $sock_data] {
      delphi_oracles $sock_data
  } elseif [string match "delphi bfp completed*" $sock_data] {
      delphi_completed $host $sock_data
  } elseif [string match "delphi solution*" $sock_data] {
      delphi_solution [string range $sock_data 16 end]
  } elseif [string match "ok child exit*" $sock_data] {
      child_exit $host
  } elseif [string match "nok kill_chil*" $sock_data] {
      nok_kill_child $host
  }
}

##########################################################################
#                delphi_solution soln                                    #
##########################################################################

proc delphi_solution soln {
  status_incr solutions
  .solutions.text insert end "\n$soln"
  .solutions.text see end
}

##########################################################################
#                delphi_started host                                     #
##########################################################################

proc delphi_started host {
  global sky_hoststatus
  set sky_hoststatus($host) running
  status_incr running
  .$host configure -background green -command "sky_kill $host"
}

##########################################################################
#                child_exit host - called on "ok child exit" from ppc    #
##########################################################################

proc child_exit host {
  global sky_hoststatus sky_exitted
  incr sky_exitted
  if { $sky_hoststatus($host) == "running" } {
    set sky_hoststatus($host) connected
    status_decr running
    .$host configure -background yellow -command "sky_disconnect $host"
  }
}

##########################################################################
#                nok_kill_child host
##########################################################################

proc nok_kill_child host {
  global sky_hoststatus
  if { $sky_hoststatus($host) == "running" } {
    set sky_hoststatus($host) connected
    status_decr running
    .$host configure -background yellow -command "sky_disconnect $host"
  }
}

##########################################################################
#                delphi_oracles {sock_data}                              #
##########################################################################

proc delphi_oracles sock_data {
  set strings [split $sock_data]
  status_set oracles [lindex $strings 6]
  status_set bf_time [lindex $strings 7]
}

##########################################################################
#                delphi_completed host                                   #
##########################################################################

proc delphi_completed {host sock_data} {
  global sky_hoststatus
  set strings [split $sock_data]
  set host_cpu_time [lindex $strings 10]
  if {$host_cpu_time > [status_read cpu_time]} {
    status_set cpu_time $host_cpu_time
  }
  status_incr completed
}

##########################################################################
#                status_incr {var_name}                                  #
##########################################################################

proc status_incr var_name {
  global sky_$var_name bfp_one_solution sky_end_run sky_solutions
  set glob_var sky_$var_name
  incr $glob_var
  .status.$var_name configure -text "$var_name:\t[set $glob_var]"
  if {($var_name == "completed") && ($sky_solutions > 0) && ($bfp_one_solution == 1)
     } { sky_kill [sky_hosts all running] ;# if 'one soln' then kill others
         set sky_end_run 1                          ;# trigger proc sky_wait
  }
}

##########################################################################
#                status_decr {var_name}                                  #
##########################################################################

proc status_decr var_name {
  global sky_$var_name sky_end_run sky_exitted
  set glob_var sky_$var_name
  set $glob_var [expr [set $glob_var] - 1]
  .status.$var_name configure -text "$var_name:\t[set $glob_var]"
  if {($var_name == "running") && ($sky_running == 0) &&
    ($sky_exitted > [expr [status_read g] / 2])} {
    set sky_end_run 1                          ;# trigger proc sky_wait
  }
}

##########################################################################
#                status_set {var_name value}                             #
##########################################################################

proc status_set {var_name value} {
  global sky_$var_name
  set glob_var sky_$var_name
  set $glob_var $value
  .status.$var_name configure -text "$var_name:\t[set $glob_var]"
}

##########################################################################
#                status_read {var_name}                                  #
##########################################################################

proc status_read var_name {
  global sky_$var_name
  return [set sky_$var_name]
}

##########################################################################
##########################################################################
# ALL SOLUTIONS: sky_bfp {{hosts} prog args}                             #
##########################################################################
##########################################################################

proc sky_bfp {host_list prog depth} {
  global bfp_one_solution sky_exitted
  set bfp_one_solution 0
  set sky_exitted 0
  status_set running 0
  status_set progname $prog
  status_set solutions 0
  status_set oracles 0
  status_set completed 0
  status_set bf_time 0
  status_set total_time 0
  status_set cpu_time 0
  status_set comms_time 0
  status_set limit $depth
  incoming_clear
  solutions_clear
  set host_count [llength $host_list]
  status_set g $host_count
  for {set i 0} {$i < $host_count} {incr i} {
    sky_send [lindex $host_list $i] "start_prog $prog $host_count $i $depth"
  }  
}
##########################################################################
##########################################################################
# ONE SOLUTION:   sky_bfp_one {{hosts} prog args}                        #
##########################################################################
##########################################################################

proc sky_bfp_one {host_list prog depth} {
  global bfp_one_solution
  sky_bfp $host_list $prog $depth
  set bfp_one_solution 1
  return {}
}


##########################################################################
##########################################################################
#                directives                                              #
##########################################################################
##########################################################################

sky_init

source skyhosts.tcl
