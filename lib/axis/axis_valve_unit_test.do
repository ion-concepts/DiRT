onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[0]/clk}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[0]/has_checks}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[0]/tdata}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[0]/tvalid}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[0]/tready}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[0]/tlast}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[1]/clk}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[1]/has_checks}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[1]/tdata}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[1]/tvalid}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[1]/tready}
add wave -noupdate {/testrunner/__ts/axis_valve_ut/axis[1]/tlast}
add wave -noupdate /testrunner/__ts/axis_valve_ut/enable
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {50592752513 fs} 0}
quietly wave cursor active 1
configure wave -namecolwidth 251
configure wave -valuecolwidth 222
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits us
update
WaveRestoreZoom {0 fs} {679657679016 fs}
