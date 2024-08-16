onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_fifo_cdc_ut/axis[0]/clk}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_fifo_cdc_ut/axis[0]/has_checks}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_fifo_cdc_ut/axis[0]/tdata}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_fifo_cdc_ut/axis[0]/tvalid}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_fifo_cdc_ut/axis[0]/tready}
add wave -noupdate -expand -group AXIS__IN {/testrunner/__ts/axis_fifo_cdc_ut/axis[0]/tlast}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_fifo_cdc_ut/axis[1]/clk}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_fifo_cdc_ut/axis[1]/has_checks}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_fifo_cdc_ut/axis[1]/tdata}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_fifo_cdc_ut/axis[1]/tvalid}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_fifo_cdc_ut/axis[1]/tready}
add wave -noupdate -expand -group AXIS_OUT {/testrunner/__ts/axis_fifo_cdc_ut/axis[1]/tlast}
add wave -noupdate -expand -group TB /testrunner/__ts/axis_fifo_cdc_ut/clk_enum
add wave -noupdate -expand -group TB /testrunner/__ts/axis_fifo_cdc_ut/rst_async
add wave -noupdate -expand -group TB /testrunner/__ts/axis_fifo_cdc_ut/axis_AXIS__IN__tdata
add wave -noupdate -expand -group TB /testrunner/__ts/axis_fifo_cdc_ut/axis_AXIS__IN__tvalid
add wave -noupdate -expand -group TB /testrunner/__ts/axis_fifo_cdc_ut/axis_AXIS__IN__tready
add wave -noupdate -expand -group TB /testrunner/__ts/axis_fifo_cdc_ut/axis_AXIS_OUT__tdata
add wave -noupdate -expand -group TB /testrunner/__ts/axis_fifo_cdc_ut/axis_AXIS_OUT__tvalid
add wave -noupdate -expand -group TB /testrunner/__ts/axis_fifo_cdc_ut/axis_AXIS_OUT__tready
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/rst
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/in_clk
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/in_tdata
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/in_tvalid
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/in_tready
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/out_clk
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/out_tdata
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/out_tvalid
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/out_tready
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/write
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/read
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/empty
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/full
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/tdata_int
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/tvalid_int
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/tready_int
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/wr_data
add wave -noupdate -expand -group UUT /testrunner/__ts/axis_fifo_cdc_ut/uut_axis_fifo_cdc/rd_data
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
WaveRestoreZoom {50483809697 fs} {50616074467 fs}
