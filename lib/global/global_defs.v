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

`define MAP_AXIS(vlog_bus_prefix, sv_interface)    \
.vlog_bus_prefix``_tready (sv_interface.tready),   \
.vlog_bus_prefix``_tvalid (sv_interface.tvalid),   \
.vlog_bus_prefix``_tdata (sv_interface.tdata),     \
.vlog_bus_prefix``_tlast (sv_interface.tlast),     \
.vlog_bus_prefix``_tkeep (sv_interface.tkeep)

`define MAP_APB(vlog_bus_prefix,sv_interface)      \
.vlog_bus_prefix``_paddr   (sv_interface.paddr),   \
.vlog_bus_prefix``_penable (sv_interface.penable), \
.vlog_bus_prefix``_pprot   (sv_interface.pprot),   \
.vlog_bus_prefix``_prdata  (sv_interface.prdata),  \
.vlog_bus_prefix``_pready  (sv_interface.pready),  \
.vlog_bus_prefix``_psel    (sv_interface.psel),    \
.vlog_bus_prefix``_pslverr (sv_interface.pslverr), \
.vlog_bus_prefix``_pstrb   (sv_interface.pstrb),   \
.vlog_bus_prefix``_pwdata  (sv_interface.pwdata),  \
.vlog_bus_prefix``_pwrite  (sv_interface.pwrite)

`define MAP_AXIL(vlog_bus_prefix,sv_interface)     \
.vlog_bus_prefix``_araddr  (sv_interface.araddr),  \
.vlog_bus_prefix``_arprot  (sv_interface.arprot),  \
.vlog_bus_prefix``_arready (sv_interface.arready), \
.vlog_bus_prefix``_arvalid (sv_interface.arvalid), \
.vlog_bus_prefix``_awaddr  (sv_interface.awaddr),  \
.vlog_bus_prefix``_awprot  (sv_interface.awprot),  \
.vlog_bus_prefix``_awready (sv_interface.awready), \
.vlog_bus_prefix``_awvalid (sv_interface.awvalid), \
.vlog_bus_prefix``_bready  (sv_interface.bready),  \
.vlog_bus_prefix``_bresp   (sv_interface.bresp),   \
.vlog_bus_prefix``_bvalid  (sv_interface.bvalid),  \
.vlog_bus_prefix``_rdata   (sv_interface.rdata),   \
.vlog_bus_prefix``_rready  (sv_interface.rready),  \
.vlog_bus_prefix``_rresp   (sv_interface.rresp),   \
.vlog_bus_prefix``_rvalid  (sv_interface.rvalid),  \
.vlog_bus_prefix``_wdata   (sv_interface.wdata),   \
.vlog_bus_prefix``_wready  (sv_interface.wready),  \
.vlog_bus_prefix``_wstrb   (sv_interface.wstrb),   \
.vlog_bus_prefix``_wvalid  (sv_interface.wvalid)

`define MAP_AXI(vlog_bus_prefix,sv_interface)     \
.vlog_bus_prefix``_araddr (sv_interface.araddr),  \
.vlog_bus_prefix``_arburst (sv_interface.arburst),\
.vlog_bus_prefix``_arcache (sv_interface.arcache),\
.vlog_bus_prefix``_arid (sv_interface.arid),      \
.vlog_bus_prefix``_arlen (sv_interface.arlen),    \
.vlog_bus_prefix``_arlock (sv_interface.arlock),  \
.vlog_bus_prefix``_arprot (sv_interface.arprot),  \
.vlog_bus_prefix``_arqos (sv_interface.arqos),    \
.vlog_bus_prefix``_arready (sv_interface.arready),\
.vlog_bus_prefix``_arsize (sv_interface.arsize),  \
.vlog_bus_prefix``_aruser (sv_interface.aruser),  \
.vlog_bus_prefix``_arvalid (sv_interface.arvalid),\
.vlog_bus_prefix``_awaddr (sv_interface.awaddr),  \
.vlog_bus_prefix``_awlen (sv_interface.awlen),    \
.vlog_bus_prefix``_awburst (sv_interface.awburst),\
.vlog_bus_prefix``_awcache (sv_interface.awcache),\
.vlog_bus_prefix``_awid (sv_interface.awid),      \
.vlog_bus_prefix``_awlock (sv_interface.awlock),  \
.vlog_bus_prefix``_awprot (sv_interface.awprot),  \
.vlog_bus_prefix``_awqos (sv_interface.awqos),    \
.vlog_bus_prefix``_awready (sv_interface.awready),\
.vlog_bus_prefix``_awsize (sv_interface.awsize),  \
.vlog_bus_prefix``_awuser (sv_interface.awuser),  \
.vlog_bus_prefix``_awvalid (sv_interface.awvalid),\
.vlog_bus_prefix``_bid (sv_interface.bid),        \
.vlog_bus_prefix``_bready (sv_interface.bready),  \
.vlog_bus_prefix``_bresp (sv_interface.bresp),    \
.vlog_bus_prefix``_bvalid (sv_interface.bvalid),  \
.vlog_bus_prefix``_rdata (sv_interface.rdata),    \
.vlog_bus_prefix``_rid (sv_interface.rid),        \
.vlog_bus_prefix``_rlast (sv_interface.rlast),    \
.vlog_bus_prefix``_rready (sv_interface.rready),  \
.vlog_bus_prefix``_rresp (sv_interface.rresp),    \
.vlog_bus_prefix``_rvalid (sv_interface.rvalid),  \
.vlog_bus_prefix``_wdata (sv_interface.wdata),    \
.vlog_bus_prefix``_wlast (sv_interface.wlast),    \
.vlog_bus_prefix``_wready (sv_interface.wready),  \
.vlog_bus_prefix``_wstrb (sv_interface.wstrb),    \
.vlog_bus_prefix``_wvalid (sv_interface.wvalid)
// Note: The BD AXI interfaces have A[WR]REGION signals, but our
// axi4_if definition does not, and there's nothing for them
// to connect to anyway.
