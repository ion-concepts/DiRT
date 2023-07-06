//-------------------------------------------------------------------------------
// File:   global_defs.v
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Global Definitions for the DiRT library.
//
//  License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------//

`timescale 1ns/1ps

// Booleans
`define FALSE 1'b0
`define TRUE 1'b1

// LOG2 function
`define LOG2(N) (\
                 N < 2 ? 0 : \
                 N < 4 ? 1 : \
                 N < 8 ? 2 : \
                 N < 16 ? 3 : \
                 N < 32 ? 4 : \
                 N < 64 ? 5 : \
                 N < 128 ? 6 : \
                 N < 256 ? 7 : \
                 N < 512 ? 8 : \
                 N < 1024 ? 9 : \
                 N < 2048 ? 10 : \
                 N < 4096 ? 11 : \
                 N < 8192 ? 12 : \
                 N < 16384 ? 13 : \
                 N < 32768 ? 14 : \
                 N < 65536 ? 15 : \
                 16)


//==========================================================================
// Macro's that map standardized System Verilog Interfaces to well named 
// buses composed of discrete signals.
//==========================================================================
// DRaT AXIS interface
`define MAP_AXIS(vlog_bus_prefix, sv_interface)    \
.vlog_bus_prefix``_tready (sv_interface.tready),   \
.vlog_bus_prefix``_tvalid (sv_interface.tvalid),   \
.vlog_bus_prefix``_tdata (sv_interface.tdata),     \
.vlog_bus_prefix``_tlast (sv_interface.tlast),     \
.vlog_bus_prefix``_tkeep (sv_interface.tkeep)
//DRaT APB interface (in Pulp style)
`define MAP_APB(vlog_bus_prefix,sv_interface)      \
.vlog_bus_prefix``_paddr   (sv_interface.p_addr),   \
.vlog_bus_prefix``_penable (sv_interface.p_enable), \
.vlog_bus_prefix``_pprot   (sv_interface.p_prot),   \
.vlog_bus_prefix``_prdata  (sv_interface.p_rdata),  \
.vlog_bus_prefix``_pready  (sv_interface.p_ready),  \
.vlog_bus_prefix``_psel    (sv_interface.p_sel),    \
.vlog_bus_prefix``_pslverr (sv_interface.p_slverr), \
.vlog_bus_prefix``_pstrb   (sv_interface.p_strb),   \
.vlog_bus_prefix``_pwdata  (sv_interface.p_wdata),  \
.vlog_bus_prefix``_pwrite  (sv_interface.p_write)
// Pulp AXI4Lite bus
`define MAP_AXIL(vlog_bus_prefix,sv_interface)     \
.vlog_bus_prefix``_araddr  (sv_interface.ar_addr),  \
.vlog_bus_prefix``_arprot  (sv_interface.ar_prot),  \
.vlog_bus_prefix``_arready (sv_interface.ar_ready), \
.vlog_bus_prefix``_arvalid (sv_interface.ar_valid), \
.vlog_bus_prefix``_awaddr  (sv_interface.aw_addr),  \
.vlog_bus_prefix``_awprot  (sv_interface.aw_prot),  \
.vlog_bus_prefix``_awready (sv_interface.aw_ready), \
.vlog_bus_prefix``_awvalid (sv_interface.aw_valid), \
.vlog_bus_prefix``_bready  (sv_interface.b_ready),  \
.vlog_bus_prefix``_bresp   (sv_interface.b_resp),   \
.vlog_bus_prefix``_bvalid  (sv_interface.b_valid),  \
.vlog_bus_prefix``_rdata   (sv_interface.r_data),   \
.vlog_bus_prefix``_rready  (sv_interface.r_ready),  \
.vlog_bus_prefix``_rresp   (sv_interface.r_resp),   \
.vlog_bus_prefix``_rvalid  (sv_interface.r_valid),  \
.vlog_bus_prefix``_wdata   (sv_interface.w_data),   \
.vlog_bus_prefix``_wready  (sv_interface.w_ready),  \
.vlog_bus_prefix``_wstrb   (sv_interface.w_strb),   \
.vlog_bus_prefix``_wvalid  (sv_interface.w_valid)
// Pulp AXI4 bus
// NOTE: Several "exotic" AXI signals omitted to due to lack of applicability.
`define MAP_AXI(vlog_bus_prefix,sv_interface)     \
.vlog_bus_prefix``_araddr (sv_interface.ar_addr),  \
.vlog_bus_prefix``_arburst (sv_interface.ar_burst),\
.vlog_bus_prefix``_arcache (sv_interface.ar_cache),\
.vlog_bus_prefix``_arid (sv_interface.ar_id),      \
.vlog_bus_prefix``_arlen (sv_interface.ar_len),    \
.vlog_bus_prefix``_arlock (sv_interface.ar_lock),  \
.vlog_bus_prefix``_arprot (sv_interface.ar_prot),  \
.vlog_bus_prefix``_arqos (sv_interface.ar_qos),    \
.vlog_bus_prefix``_arready (sv_interface.ar_ready),\
.vlog_bus_prefix``_arsize (sv_interface.ar_size),  \
.vlog_bus_prefix``_aruser (sv_interface.ar_user),  \
.vlog_bus_prefix``_arvalid (sv_interface.ar_valid),\
.vlog_bus_prefix``_awaddr (sv_interface.aw_addr),  \
.vlog_bus_prefix``_awlen (sv_interface.aw_len),    \
.vlog_bus_prefix``_awburst (sv_interface.aw_burst),\
.vlog_bus_prefix``_awcache (sv_interface.aw_cache),\
.vlog_bus_prefix``_awid (sv_interface.aw_id),      \
.vlog_bus_prefix``_awlock (sv_interface.aw_lock),  \
.vlog_bus_prefix``_awprot (sv_interface.aw_prot),  \
.vlog_bus_prefix``_awqos (sv_interface.aw_qos),    \
.vlog_bus_prefix``_awready (sv_interface.aw_ready),\
.vlog_bus_prefix``_awsize (sv_interface.aw_size),  \
.vlog_bus_prefix``_awuser (sv_interface.aw_user),  \
.vlog_bus_prefix``_awvalid (sv_interface.aw_valid),\
.vlog_bus_prefix``_bid (sv_interface.b_id),        \
.vlog_bus_prefix``_bready (sv_interface.b_ready),  \
.vlog_bus_prefix``_bresp (sv_interface.b_resp),    \
.vlog_bus_prefix``_bvalid (sv_interface.b_valid),  \
.vlog_bus_prefix``_rdata (sv_interface.r_data),    \
.vlog_bus_prefix``_rid (sv_interface.r_id),        \
.vlog_bus_prefix``_rlast (sv_interface.r_last),    \
.vlog_bus_prefix``_rready (sv_interface.r_ready),  \
.vlog_bus_prefix``_rresp (sv_interface.r_resp),    \
.vlog_bus_prefix``_rvalid (sv_interface.r_valid),  \
.vlog_bus_prefix``_wdata (sv_interface.w_data),    \
.vlog_bus_prefix``_wlast (sv_interface.w_last),    \
.vlog_bus_prefix``_wready (sv_interface.w_ready),  \
.vlog_bus_prefix``_wstrb (sv_interface.w_strb),    \
.vlog_bus_prefix``_wvalid (sv_interface.w_valid)

