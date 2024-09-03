//-------------------------------------------------------------------------------
// File:   global_defs.svh
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Global Definitions for the DiRT library.
//
//  License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`timescale 1ns/1ps

// Booleans
`define FALSE 1'b0
`define TRUE 1'b1

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
// RFDC style 3 signal version of AXIS for streaming i/f
`define MAP_AXIS_RFDC(vlog_bus_prefix, sv_interface)    \
.vlog_bus_prefix``_tready (sv_interface.tready),   \
.vlog_bus_prefix``_tvalid (sv_interface.tvalid),   \
.vlog_bus_prefix``_tdata (sv_interface.tdata)
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

`define MAP_AXI_READ(vlog_bus_prefix,sv_interface)  \
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
.vlog_bus_prefix``_rdata (sv_interface.r_data),    \
.vlog_bus_prefix``_rid (sv_interface.r_id),        \
.vlog_bus_prefix``_rlast (sv_interface.r_last),    \
.vlog_bus_prefix``_rready (sv_interface.r_ready),  \
.vlog_bus_prefix``_rresp (sv_interface.r_resp),    \
.vlog_bus_prefix``_rvalid (sv_interface.r_valid)

`define MAP_AXI_WRITE(vlog_bus_prefix,sv_interface) \
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
.vlog_bus_prefix``_wdata (sv_interface.w_data),    \
.vlog_bus_prefix``_wlast (sv_interface.w_last),    \
.vlog_bus_prefix``_wready (sv_interface.w_ready),  \
.vlog_bus_prefix``_wstrb (sv_interface.w_strb),    \
.vlog_bus_prefix``_wvalid (sv_interface.w_valid)

`define MAP_AXI(vlog_bus_prefix,sv_interface)     \
`MAP_AXI_READ(vlog_bus_prefix,sv_interface),      \
`MAP_AXI_WRITE(vlog_bus_prefix,sv_interface)

// GMII interface (Discrete signal naming follows Xiinx Vivado BD generated names)
`define MAP_GMII(gmii_bus_prefix, sv_interface) \
.gmii_bus_prefix``_tx_clk (sv_interface.txclk), \
.gmii_bus_prefix``_txd (sv_interface.txd),      \
.gmii_bus_prefix``_tx_en (sv_interface.txen),   \
.gmii_bus_prefix``_tx_er (sv_interface.txer),   \
.gmii_bus_prefix``_rx_clk (sv_interface.rxclk), \
.gmii_bus_prefix``_rxd (sv_interface.rxd),    \
.gmii_bus_prefix``_rx_dv (sv_interface.rxdv), \
.gmii_bus_prefix``_rx_er (sv_interface.rxer), \
.gmii_bus_prefix``_col (sv_interface.col),    \
.gmii_bus_prefix``_crs (sv_interface.cs)

// MDIO interface (Discrete signal naming follows Xiinx Vivado BD generated names)
`define MAP_MDIO(mdio_bus_prefix, sv_interface) \
.mdio_bus_prefix``_mdc (sv_interface.mdc),      \
.mdio_bus_prefix``_mdio_i (sv_interface.mdi),   \
.mdio_bus_prefix``_mdio_o (sv_interface.mdo),   \
.mdio_bus_prefix``_mdio_t (sv_interface.mdt)
