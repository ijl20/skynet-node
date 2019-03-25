
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
#    sky_hoststatus: array $host -> status: shutdown:    ppc has died
#                                           closed:      disconnected from ppc
#                                           connected:   skynet connected to ppc
#                                           loaded:      user prog loaded
#                                           starting:    initial o_k issued
#                                           running:     user prog running
#                                           interrupted: child interrupt sent
#                                           deferred:    child has deferred interrupt
#                                           waiting:     user prog completed
#                                           primed:      host selected for work split
#  
#  Globals for "status" window: 
#    sky_available sky_connected sky_running sky_oracles sky_bf_time
#    sky_solutions sky_cpu_time sky_comms_time sky_total_time
#    sky_completed sky_progname sky_limit
#    sky_waiting sky_loaded
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
#    sky_host_started($host) = number of times host has completed
#    sky_host_interrupted($host) = number of times host has been interrupted
#
#    sky_host_h($host) = group count for host $host
#    sky_host_n($host)
#    sky_host_l($host)
#    sky_host_oracle($host) = port oracle for $host
#
#    sky_console_hostname:  hostname set in dialog from "sky_console_ask"
#
#    sky_kappa_running:     structure to hold ordered list of running hosts
#
#    k_utils:               version of k_utils being used:
#                            0: k_utils, k1_utils: orcs limited to PORTS only
#                            1: k1_utils: full current orc returned
#    kappa_split_g:         count of 'waiting' PP's required before split
#    kappa_l:               initial depth limit L
#    kappa_l1:              depth increment after split
#    kappa_g:               initial group count G
#    kappa_g1:              new group count on each split ( <= kappa_split_g )
#    kappa_fixed:           1 => fixed incremental depth, 0 => doubling
#
#    starttime
#    log_incoming:          1 => incoming messages logged to ".incoming" window
#


##########################################################################
#                2015 change log                                         #
##########################################################################
#
#   2015-05-18  changed hostname suffix to csi.cam.ac.uk
#
##########################################################################
#                sky_init                                                #
##########################################################################

proc sky_init {} {
  global tk_strictMotif
  global current_frame frame_count
  global sky_available sky_connected sky_running sky_oracles sky_bf_time
  global sky_solutions sky_cpu_time sky_comms_time sky_total_time
  global sky_completed sky_progname sky_limit sky_exitted sky_waiting sky_loaded
  global sky_g
  global sky_started
  global sky_end_run
  global sky_host_started sky_host_interrupted
  global k_utils
  global bfp_one_solution

  global sky_kappa_running
  global kappa_split_g kappa_l kappa_l1 kappa_g1 kappa_fixed

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
  set sky_waiting    0
  set sky_loaded     0

  set bfp_one_solution 0

  set k_utils 1
  set sky_kappa_running {}

  set kappa_l 2
  set kappa_l1 2
  set kappa_split_g 3
  set kappa_g1 3
  set kappa_fixed 0

  wm title . "Skynet"
  wm geometry . 480x400+20+40
  frame .mbar -relief raised -bd 2
  pack .mbar -side top -fill x
  menubutton .mbar.file -text File -menu .mbar.file.menu
  menu .mbar.file.menu
  .mbar.file.menu add command -label Close -command close_skynet
  menubutton .mbar.commands -text Commands -menu .mbar.commands.menu
  menu .mbar.commands.menu
  .mbar.commands.menu add command -label "Connect all" -command connect_all
  .mbar.commands.menu add command -label "Kill all" -command kill_all
  .mbar.commands.menu add command -label "Disconnect all" -command disconnect_all
  .mbar.commands.menu add command -label "Console" -command console_ask
  menubutton .mbar.window -text Window -menu .mbar.window.menu
  menu .mbar.window.menu
  .mbar.window.menu add command -label Incoming -command create_incoming
  pack .mbar.file .mbar.commands .mbar.window -side left

  set current_frame 0
  set frame_count 4
  for {set i 0} {$i < $frame_count} {incr i} {
    frame .frame$i -width 90
    pack .frame$i -side left -fill y
    }

  create_incoming 

  toplevel .solutions
  wm title .solutions "Solutions"
  wm geometry .solutions 480x360+765+40
  text .solutions.text -bd 2 -yscrollcommand ".solutions.scroll set"
  scrollbar .solutions.scroll -command ".solutions.text yview"
  pack .solutions.scroll -side right -fill y
  pack .solutions.text -side left -fill both -expand 1

  toplevel .status
  wm title .status "Status"
  wm geometry .status 220x300+530+40
  label .status.progname   -text "Progname:"
  label .status.available  -text "Available:\t 0"
  label .status.connected  -text "Connected:\t 0"
  label .status.loaded     -text "Loaded:\t 0"
  label .status.running    -text "Running:\t 0"
  label .status.waiting    -text "Waiting:\t 0"
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
  pack .status.available .status.connected -anchor w
  pack .status.loaded    .status.running -anchor w
  pack .status.waiting .status.completed -anchor w
  pack .status.oracles .status.cpu_time .status.comms_time -anchor w
  pack .status.bf_time .status.solutions  -anchor w
  pack .status.total_time .status.limit .status.g -anchor w

  return ""
}

proc create_incoming {} {
  global log_incoming
  set log_incoming 1
  toplevel .incoming
  wm title .incoming "Incoming"
  wm geometry .incoming 600x360+550+440
  frame .incoming.mbar -relief raised -bd 2
  pack .incoming.mbar -side top -fill x
  menubutton .incoming.mbar.file -text File -menu .incoming.mbar.file.menu
  menu .incoming.mbar.file.menu
  .incoming.mbar.file.menu add command -label Close -command close_incoming
  .incoming.mbar.file.menu add command -label Clear -command incoming_clear
  text .incoming.text -bd 2 -yscrollcommand ".incoming.scroll set"
  scrollbar .incoming.scroll -command ".incoming.text yview"
  pack .incoming.mbar.file -side left
  pack .incoming.scroll -side right -fill y
  pack .incoming.text -side left -fill both -expand 1
}

proc close_incoming {} {
  global log_incoming
  set log_incoming 0
  destroy .incoming
}

proc incoming_clear {} {
  global log_incoming
    if {$log_incoming} {.incoming.text delete 1.0 end}
}


proc solutions_clear {} {
  .solutions.text delete 1.0 end
}

##########################################################################
#                close_skynet                                            #
##########################################################################

proc close_skynet {} {
  kill_all
  disconnect_all
  exit
}

##########################################################################
#                connect_all                                             #
##########################################################################

proc connect_all {} {
  sky_connect [sky_hosts all closed]
}

##########################################################################
#                kill_all                                                #
##########################################################################

proc kill_all {} {
  sky_kill [sky_hosts all loaded]
  sky_kill [sky_hosts all starting]
  sky_kill [sky_hosts all running]
  sky_kill [sky_hosts all interrupted]
  sky_kill [sky_hosts all deferred]
  sky_kill [sky_hosts all waiting]
  sky_kill [sky_hosts all primed]
}

##########################################################################
#                disconnect_all                                          #
##########################################################################

proc disconnect_all {} {
  sky_disconnect [sky_hosts]
}

##########################################################################
#                console_ask                                             #
##########################################################################

proc console_ask {} {
  global sky_console_hostname
  toplevel .console_prompt
  wm title .console_prompt "Console host?"
  message .console_prompt.message -text "Hostname for console?"
  entry .console_prompt.entry -relief sunken -bd 2 -textvariable sky_console_hostname
  button .console_prompt.ok -text Ok -command console_ask_ok
  button .console_prompt.cancel -text Cancel -command console_ask_cancel
  pack .console_prompt.message -side top -fill x
  pack .console_prompt.entry -fill x
  pack .console_prompt.ok .console_prompt.cancel
  bind .console_prompt.entry <Return> console_ask_ok
}

proc console_ask_ok {} {
  global sky_console_hostname
  destroy .console_prompt
  sky_console  $sky_console_hostname
}

proc console_ask_cancel {} {
  destroy .console_prompt
}

##########################################################################
#                sky_console host                                        #
##########################################################################

proc sky_console host {
  toplevel .console_$host
  wm title .console_$host "Skynet Console: $host"
  wm geometry .console_$host 600x360
  text .console_$host.text -bd 2 -yscrollcommand ".console_$host.scroll set"
  scrollbar .console_$host.scroll -command ".console_$host.text yview"
  entry .console_$host.entry -relief sunken -bd 2 -fg red

  frame .console_$host.mbar -relief raised -bd 2
  pack .console_$host.mbar -side top -fill x
  menubutton .console_$host.mbar.file -text File -menu .console_$host.mbar.file.menu
  menu .console_$host.mbar.file.menu
  .console_$host.mbar.file.menu add command -label Close -command "close_console $host"
  menubutton .console_$host.mbar.commands -text Commands -menu .console_$host.mbar.commands.menu
  menu .console_$host.mbar.commands.menu
  .console_$host.mbar.commands.menu add command -label Clear -command "clear_console $host"
  pack .console_$host.mbar.file .console_$host.mbar.commands -side left

  pack .console_$host.entry -side bottom -fill x
  pack .console_$host.scroll -side right -fill y
  pack .console_$host.text -side left -fill y

  .console_$host.text tag configure to_host -foreground blue
  .console_$host.text tag configure from_console -foreground red

  set next 1.0
  set host_length [expr [string length $host]+2]
  while {[set i [.incoming.text search "<$host>" $next end]] != ""} {
    set l [string range [lindex [.incoming.text dump -text $i "$i + 1 line"] 1] $host_length end]
    .console_$host.text insert end $l
    set next "$i + 1 char"
  } 
}

##########################################################################
#                close_console host                                      #
##########################################################################

proc close_console host {
  destroy .console_$host
}

##########################################################################
#                clear_console host                                      #
##########################################################################

proc clear_console host {
  .console_$host.text delete 1.0 end
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
  global sky_host_started sky_host_interrupted
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i]
    set sky_hoststatus($host) closed
    set sky_host_started($host) 0
    set sky_host_interrupted($host) 0
    status_incr available
    set host_text "$host"
    button .$host -text $host_text -background grey -command "sky_connect $host"
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
      set connect_bad [catch {set sock [socket -async $host.csi.cam.ac.uk 6173]}]
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
  global sky_hostsock
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i] 
    sky_send $host "kill_child"
  }
}
 
##########################################################################
#                sky_interrupt {host_list}                               #
##########################################################################

proc sky_interrupt host_list {
  global sky_hostsock sky_hoststatus sky_host_interrupted
  set host_count [llength $host_list]
  for {set i 0} {$i < $host_count} {incr i} {
    set host [lindex $host_list $i] 
    set sky_hoststatus($host) interrupted
    incr sky_host_interrupted($host)
    .$host configure -foreground white
    sky_send $host "interrupt_child"
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
  global log_incoming
  set sock_data [gets $sock]
  if {$sock_data == ""} { 
#    puts "debug: read_sock got nil data from <$host>"
#    sky_disconnect $host
#    .incoming.text insert end "\n<$host>disconnected"
#    .incoming.text see end    
  } else {
      if {$log_incoming} {
        .incoming.text insert end "\n<$host>$sock_data"
        .incoming.text see end
        if {[winfo exists .console_$host]} {
           .console_$host.text insert end "\n$sock_data"
           .console_$host.text see end
      }
    }
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
    if {[winfo exists .console_$host]} {
       .console_$host.text insert end "\n$msg" to_host
       .console_$host.text see end
    }
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
#                scan_stream host sock_data                              #
##########################################################################

proc scan_stream {host sock_data} {
  if [string match "ok sky_connect*" $sock_data] {
      ok_sky_connect $host
  } elseif [string match "delphi solution*" $sock_data] {
      delphi_solution [string range $sock_data 16 end]
  } elseif [string match "delphi bfp*" $sock_data] {
      scan_bfp $host $sock_data
  } elseif [string match "delphi kappa*" $sock_data] {
      scan_kappa $host $sock_data
  } elseif [string match "ok child exit*" $sock_data] {
      child_exit $host
  } elseif [string match "nok kill_chil*" $sock_data] {
      nok_kill_child $host
  }
}

##########################################################################
#                scan_bfp host sock_data                                 #
##########################################################################

proc scan_bfp {host sock_data} {
  if [string match "delphi bfp started*" $sock_data] {
      delphi_started $host
  } elseif [string match "delphi bfp oracles*" $sock_data] {
      delphi_oracles $sock_data
  } elseif [string match "delphi bfp completed*" $sock_data] {
      delphi_completed $host $sock_data
  }
}

##########################################################################
#                scan_kappa host sock_data                               #
##########################################################################

proc scan_kappa {host sock_data} {
  if [string match "delphi kappa loaded*" $sock_data] {
      kappa_loaded $host
  } elseif [string match "delphi kappa started*" $sock_data] {
      kappa_started $host $sock_data
  } elseif [string match "delphi kappa oracle*" $sock_data] {
      kappa_oracle $host $sock_data
  } elseif [string match "delphi kappa deferred*" $sock_data] {
      kappa_deferred $host
  } elseif [string match "delphi kappa completed*" $sock_data] {
      kappa_completed $host $sock_data
  } elseif [string match "delphi kappa nosplit*" $sock_data] {
      kappa_nosplit $host
  }
}

##########################################################################
#                kappa_loaded host                                       #
##########################################################################

proc kappa_loaded host {
  global sky_hoststatus k_utils
  global sky_host_g sky_host_n sky_host_l sky_host_oracle kappa_g starttime
  status_incr loaded
  set sky_hoststatus($host) loaded
  .$host configure -background lightblue -command ""
  if { [status_read loaded] == $kappa_g } {
    set starttime [clock seconds]
    foreach h [array names sky_hoststatus] {
      if { $sky_hoststatus($h) == "loaded" } {
        set sky_hoststatus($h) starting
        if {$k_utils == 0} {
          set o_k "o_k($sky_host_g($h),$sky_host_n($h),$sky_host_l($h),$sky_host_oracle($h))."
          } elseif { $k_utils == 1 } {
          set o_k "o_k($sky_host_g($h),$sky_host_n($h),0,$sky_host_l($h),$sky_host_oracle($h))."
        }
        sky_send $h "send_child $o_k"
      }
    }
  }
}

##########################################################################
#                kappa_started host sock_data                            #
##########################################################################

proc kappa_started {host sock_data} {
  global sky_hoststatus sky_host_started sky_host_l sky_host_interrupted 
  set sky_hoststatus($host) running
  add_running $host [lindex [split $sock_data] 5]
  status_incr running
  .$host configure -background green -command "sky_interrupt $host"
  incr sky_host_started($host)
  .$host configure -text "$host $sky_host_l($host) $sky_host_interrupted($host) $sky_host_started($host)"
}

##########################################################################
#                kappa_oracle host sock_data                             #
##########################################################################

proc kappa_oracle {host sock_data} {
  global sky_host_interrupted sky_host_started sky_hoststatus
  global sky_host_g sky_host_n sky_host_l

  set sky_hoststatus($host) running
  .$host configure -text "$host $sky_host_l($host) $sky_host_interrupted($host) $sky_host_started($host)" -fg black
#  puts "debug: received oracle from <$host>"
  add_running $host $sky_host_l($host)
  kappa_split_assign $host $sock_data
}

##########################################################################
#                kappa_completed host                                    #
##########################################################################

proc kappa_completed {host sock_data} {
  global sky_hoststatus sky_host_interrupted kappa_split_g

#  puts "debug: $sky_hoststatus($host) <$host> completed"

  if {$sky_hoststatus($host) == "interrupted"} {
#    set sky_hoststatus($host) waiting
#    reset_primed $kappa_split_g    
  } else {
    if {$sky_hoststatus($host) == "deferred"} { 
      reset_primed $kappa_split_g
    }
    set strings [split $sock_data]
    set host_cpu_time [lindex $strings 10]
    if {$host_cpu_time > [status_read cpu_time]} {
      status_set cpu_time $host_cpu_time
    }
    .$host configure -background lightblue -command "" -fg black
    set sky_hoststatus($host) waiting
    remove_running $host
    status_incr completed
    status_decr running
    status_incr waiting
  }
  if { [kappa_split_test] } {kappa_split}
}

##########################################################################
#                kappa_deferred host                                     #
##########################################################################

proc kappa_deferred host {
  global sky_hoststatus
  set sky_hoststatus($host) deferred
}

##########################################################################
#                kappa_nosplit host                                      #
##########################################################################

proc kappa_nosplit host {
  global sky_hoststatus kappa_split_g
  global sky_host_g sky_host_n sky_host_l sky_host_oracle
  .$host configure -fg black
#  puts "debug: kappa_nosplit received from <$host>, status $sky_hoststatus($host)"
  if { $sky_hoststatus($host) == "interrupted" } {
    reset_primed $kappa_split_g
    set sky_hoststatus($host) running
    kappa_completed $host "0 0 0 0 0 0 0 0 0 0 0 0"
  } else { kappa_split }
}

##########################################################################
#                delphi_solution soln                                    #
##########################################################################

proc delphi_solution soln {
  global starttime
  status_incr solutions
  set runtime [expr [clock seconds] - $starttime]
  .solutions.text insert end "\n\[$runtime\] $soln"
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
  if { ($sky_hoststatus($host) == "running")      || \
       ($sky_hoststatus($host) == "loaded")       || \
       ($sky_hoststatus($host) == "starting")     || \
       ($sky_hoststatus($host) == "waiting")      || \
       ($sky_hoststatus($host) == "interrupted")  || \
       ($sky_hoststatus($host) == "primed")  } {
    if { $sky_hoststatus($host) == "interrupted" }  {
      status_decr running
      puts "debug: child exit from interrupted host <$host>"
    } elseif { $sky_hoststatus($host) == "running" }  {
      status_decr running
      remove_running $host
#      puts "debug: child exit from running host <$host>"
    }
    set sky_hoststatus($host) connected
    .$host configure -background yellow -command "sky_disconnect $host" -fg black
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
    remove_running $host
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
  global kappa_g kappa_g1 kappa_split_g kappa_l kappa_l1 starttime
  set glob_var sky_$var_name
  incr $glob_var
  .status.$var_name configure -text "$var_name:\t[set $glob_var]"
  if {($var_name == "waiting") && ($sky_waiting == $kappa_g)} {
    set runtime [expr [clock seconds] - $starttime]
    status_set total_time $runtime
    puts "runtime [status_read progname] $kappa_g $kappa_split_g $kappa_g1 \
            $kappa_l $kappa_l1 $runtime"
    sky_kill [sky_hosts all waiting]
  }
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
#                add_running host depth                                  #
##########################################################################

proc add_running {host depth} {
  global sky_kappa_running
  set i 0
  set running_count [llength $sky_kappa_running]
  while { $i < $running_count} {
    set current_depth [lindex [lindex $sky_kappa_running $i] 0]
    if { $depth == $current_depth } {
      set new_hosts [concat [lindex $sky_kappa_running $i] $host]
      set sky_kappa_running [lreplace $sky_kappa_running $i $i $new_hosts]
      break
    } elseif { $depth < $current_depth } {
      set sky_kappa_running [linsert $sky_kappa_running $i "$depth $host"]
      break
    } else {
      incr i
    }
  }
  if { $i == $running_count } {
    lappend sky_kappa_running "$depth $host"
  }
}

##########################################################################
#                get_running {}                                          #
##########################################################################

proc get_running {} {
  global sky_kappa_running
  if {$sky_kappa_running == {}} { return {}
  } else {
    set current_hosts [lindex $sky_kappa_running 0]
    set host_count [llength $current_hosts]
    set host [lindex $current_hosts 1]
    set depth [lindex $current_hosts 0]
    set new_hosts [concat $depth [lrange $current_hosts 2 [expr $host_count - 1]]]
    lappend new_hosts $host
    set sky_kappa_running [lreplace $sky_kappa_running 0 0 $new_hosts]
    return $host
  }
}

##########################################################################
#                remove_running host                                     #
##########################################################################

proc remove_running host {
  global sky_kappa_running
  set maxi [llength $sky_kappa_running]
  set i 0
  while {$i < $maxi} {
    set j 1
    set maxj [llength [lindex $sky_kappa_running $i]]
    while {$j < $maxj} {
      if { [lindex [lindex $sky_kappa_running $i] $j] == $host } {
        if { $maxj == 2 } {
          set depths_below [lrange $sky_kappa_running 0 [expr $i - 1]]
          set depths_above [lrange $sky_kappa_running [expr $i + 1] $maxi]
          set sky_kappa_running [concat $depths_below $depths_above]
          set j $maxj
          set i $maxi
        } else {
          set hosts_before [lrange [lindex $sky_kappa_running $i] 0 [expr $j -1]]
          set hosts_after [lrange [lindex $sky_kappa_running $i] [expr $j + 1] $maxj]
          set sky_kappa_running [lreplace $sky_kappa_running $i $i \
                   [concat $hosts_before $hosts_after]]
          set j $maxj
          set i $maxi
        }
      }
      incr j
    }
    incr i
  }
#  if {$i == $maxi} {puts "debug: host <$host> not found in remove_running"}
}

##########################################################################
#                kappa_split_test                                        #
##########################################################################

proc kappa_split_test {} {
  global kappa_split_g kappa_g sky_waiting sky_hoststatus 

  if { $sky_waiting == $kappa_g } {return 0}

  set waiting_count 0
  set primed_list {}
  foreach host [array names sky_hoststatus] {
    if { $sky_hoststatus($host) == "waiting" } {
      status_decr waiting
      set sky_hoststatus($host) primed
      lappend primed_list $host
      incr waiting_count
      if { $waiting_count == $kappa_split_g } { 
#        puts "debug: primed $primed_list"
        return 1 
      }
    }
  }
  reset_primed $waiting_count
  return 0
}

##########################################################################
#                kappa_split                                             #
##########################################################################

proc kappa_split {} {
  global kappa_split_g sky_hoststatus
  set host [get_running]
  if {$host != ""} {
    remove_running $host
#    puts "debug: interrupting $sky_hoststatus($host) <$host>"
    sky_interrupt $host
  } else {
#    puts "debug: no running hosts to interrupt"
    reset_primed $kappa_split_g
  }
}

##########################################################################
#                kappa_split_assign from_host sock_data                  #
##########################################################################

proc kappa_split_assign {from_host sock_data} {
  global sky_hoststatus k_utils
  global sky_host_started
  global sky_host_g sky_host_n sky_host_l sky_host_oracle
  global kappa_g1 kappa_l1 kappa_fixed

  set strings [split $sock_data]
  set g $kappa_g1
  set n 0
  set prev_l [lindex $strings 5]
  if {$kappa_fixed} { set l [expr $prev_l+$kappa_l1]    ;# fixed increment
  } else { set l [expr $prev_l * 2]          ;# doubling
  }
  set orc [lindex $strings 7]
  set host_list {}
  foreach host [array names sky_hoststatus] {
      if {$sky_hoststatus($host) == "primed"} { 
        lappend host_list $host
        set sky_hoststatus($host) starting
        set sky_host_g($host) $g
        set sky_host_n($host) $n
        set sky_host_l($host) $l
        set sky_host_oracle($host) $orc
        if { $k_utils == 0 } {
          set o_k "o_k($g,$n,$l,$orc)."            ;# version for k_utils
	  } elseif { $k_utils == 1 } {
          set o_k "o_k($g,$n,$prev_l,$l,$orc)."     ;# version for k1_utils
        }
        sky_send $host "send_child $o_k"
        incr n
        if { $n == $g } {
           puts "debug: assigning from <$prev_l,$from_host> to <$l, $host_list>"
           break }
      }
  }

}

##########################################################################
#                reset_primed count                                      #
##########################################################################

proc reset_primed count {
  global sky_hoststatus kappa_split_g
  set i $count
  set reset_hosts {}
  foreach host [array names sky_hoststatus] {
    if { $i == 0 } { break }
    if { $sky_hoststatus($host) == "primed" } {
      set sky_hoststatus($host) waiting
      status_incr waiting
      lappend reset_hosts $host
      incr i -1
    }
  }
#  if {$count == $kappa_split_g} {puts "debug: reset to waiting $reset_hosts"}
}

##########################################################################
#                sky_status                                              #
##########################################################################

proc sky_status {} {
  global sky_hoststatus
  set status_list {shutdown closed connected loaded starting running waiting \
                  interrupted deferred primed}
  foreach status $status_list {
    set $status {}
    set count($status) 0
  }
  foreach host [array names sky_hoststatus] {
    set s $sky_hoststatus($host)
    foreach status $status_list {
      if { $s == $status}  {
        lappend $status $host
        incr count($status)
      }
    }
  }
  foreach status $status_list {
    puts "$status\($count($status)\) [set $status]"
  }
}

##########################################################################
##########################################################################
# ALL SOLUTIONS: sky_bfp {{hosts} prog depth}                            #
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
# ONE SOLUTION:   sky_bfp_one {{hosts} prog depth}                       #
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
# sky_kappa host_list prog depth                                         #
##########################################################################
##########################################################################

proc sky_kappa {host_list prog} {
  global bfp_one_solution sky_exitted
  global sky_host_started sky_host_interrupted
  global sky_host_g sky_host_n sky_host_l sky_host_oracle
  global kappa_l kappa_g

  set bfp_one_solution 0
  set sky_exitted 0
  status_set running 0
  status_set waiting 0
  status_set loaded  0
  status_set progname $prog
  status_set solutions 0
  status_set oracles 0
  status_set completed 0
  status_set bf_time 0
  status_set total_time 0
  status_set cpu_time 0
  status_set comms_time 0
  status_set limit $kappa_l
  incoming_clear
  solutions_clear
  set kappa_g [llength $host_list]
  status_set g $kappa_g
  for {set n 0} {$n < $kappa_g} {incr n} {
    set host [lindex $host_list $n]
    set sky_host_started($host) 0
    set sky_host_interrupted($host) 0
    set sky_host_g($host) $kappa_g
    set sky_host_n($host) $n
    set sky_host_l($host) $kappa_l
    set sky_host_oracle($host) "\[\]"
    .$host configure -text "$host 0 0 0" -fg black
    sky_send [lindex $host_list $n] "start_prog $prog"
  }  
}

##########################################################################
##########################################################################
#                user progs                                              #
##########################################################################
##########################################################################

proc pent_recurs host_list {
  global kappa_g1 kappa_l kappa_l1 kappa_split_g
  set kappa_g1 2
  set kappa_l 3
  set kappa_l1 5
  set kappa_split_g 2
  sky_kappa $host_list pent_recurs
}

##########################################################################
##########################################################################
#                directives                                              #
##########################################################################
##########################################################################

sky_init

source skyhosts.tcl

