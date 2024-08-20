onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_siggen_ut/axis[0]/clk}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_siggen_ut/axis[0]/has_checks}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_siggen_ut/axis[0]/tdata}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_siggen_ut/axis[0]/tvalid}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_siggen_ut/axis[0]/tready}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_siggen_ut/axis[0]/tlast}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_siggen_ut/axis[1]/clk}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_siggen_ut/axis[1]/has_checks}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_siggen_ut/axis[1]/tdata}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_siggen_ut/axis[1]/tvalid}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_siggen_ut/axis[1]/tready}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_siggen_ut/axis[1]/tlast}
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/AXIS_DWIDTH
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/axis_vif
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/clk
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/clk_enum
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/clk_period
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/enable
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/name
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/NUM_AXIS
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/NUM_CLK
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/phase_i
add wave -noupdate -expand -group TB -format Analog-Step -height 84 -max 32767.0 -min -32768.0 -radix decimal /testrunner/__ts/axis_siggen_ut/phase_i
add wave -noupdate -expand -group TB -format Analog-Step -height 84 -max 65343.999999999993 -radix unsigned /testrunner/__ts/axis_siggen_ut/phase_q
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/phase_i_delay
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/phase_inc
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/phase_q
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/phase_q_delay
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/rst
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/rst_async
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/svunit_ut
add wave -noupdate -expand -group TB /testrunner/__ts/axis_siggen_ut/waveform
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_siggen_ut/uut_axis_siggen/clk
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_siggen_ut/uut_axis_siggen/rst
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_siggen_ut/uut_axis_siggen/enable_in
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_siggen_ut/uut_axis_siggen/phase_inc_in
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_siggen_ut/uut_axis_siggen/waveform_in
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_siggen_ut/uut_axis_siggen/phase
TreeUpdate [SetDefaultTree]
WaveRestoreCursors
quietly wave cursor active 0
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
WaveRestoreZoom {0 fs} {243190743977 fs}
