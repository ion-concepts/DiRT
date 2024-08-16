onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group AXIS__IN {/testrunner/__ts/axis_deframer_ut/axis[0]/clk}
add wave -noupdate -group AXIS__IN {/testrunner/__ts/axis_deframer_ut/axis[0]/has_checks}
add wave -noupdate -group AXIS__IN {/testrunner/__ts/axis_deframer_ut/axis[0]/tdata}
add wave -noupdate -group AXIS__IN {/testrunner/__ts/axis_deframer_ut/axis[0]/tvalid}
add wave -noupdate -group AXIS__IN {/testrunner/__ts/axis_deframer_ut/axis[0]/tready}
add wave -noupdate -group AXIS__IN {/testrunner/__ts/axis_deframer_ut/axis[0]/tlast}
add wave -noupdate -group AXIS_OUT {/testrunner/__ts/axis_deframer_ut/axis[1]/clk}
add wave -noupdate -group AXIS_OUT {/testrunner/__ts/axis_deframer_ut/axis[1]/has_checks}
add wave -noupdate -group AXIS_OUT {/testrunner/__ts/axis_deframer_ut/axis[1]/tdata}
add wave -noupdate -group AXIS_OUT {/testrunner/__ts/axis_deframer_ut/axis[1]/tvalid}
add wave -noupdate -group AXIS_OUT {/testrunner/__ts/axis_deframer_ut/axis[1]/tready}
add wave -noupdate -group AXIS_OUT {/testrunner/__ts/axis_deframer_ut/axis[1]/tlast}
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/clk
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/rst
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/enable_in
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/async
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/odd_length
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/end_of_burst
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/seq_num
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/flow_id
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/timestamp
add wave -noupdate -expand -group DUT /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/state
add wave -noupdate -expand -group axis_pkt_in /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_pkt_in/clk
add wave -noupdate -expand -group axis_pkt_in /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_pkt_in/has_checks
add wave -noupdate -expand -group axis_pkt_in /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_pkt_in/tdata
add wave -noupdate -expand -group axis_pkt_in /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_pkt_in/tvalid
add wave -noupdate -expand -group axis_pkt_in /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_pkt_in/tready
add wave -noupdate -expand -group axis_pkt_in /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_pkt_in/tlast
add wave -noupdate -expand -group axis_tail_out /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_tail_out/clk
add wave -noupdate -expand -group axis_tail_out /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_tail_out/has_checks
add wave -noupdate -expand -group axis_tail_out /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_tail_out/tdata
add wave -noupdate -expand -group axis_tail_out /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_tail_out/tvalid
add wave -noupdate -expand -group axis_tail_out /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_tail_out/tready
add wave -noupdate -expand -group axis_tail_out /testrunner/__ts/axis_deframer_ut/uut_axis_deframer/axis_tail_out/tlast
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {614624027634 fs} 0}
quietly wave cursor active 1
configure wave -namecolwidth 157
configure wave -valuecolwidth 154
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
WaveRestoreZoom {614375359108 fs} {615464675084 fs}
