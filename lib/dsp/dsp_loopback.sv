
+//----------------------------------------------------------------------------
// File:    dsp_loopback.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// "Near Loopback" - Loopback immediately adjacent to framer/deframer.
// Assumes AXIS on framer side and just qualified sample on DSP side.
//
// License: CERN-OHL-P (See LICENSE.md)
//-----------------------------------------------------------------------------


module dsp_loopback
  (
   input logic         clk,
   input logic         rst,
   // CSR
   input logic         csr_loopback_enable,
   // TX Sample stream in
   //axis_t.slave axis_tx_stream,
   input logic [31:0]  tx_tdata_in,
   input logic         tx_tvalid_in,
   output logic        tx_tready_out,
   input logic         tx_tlast_in,
   // TX Sample stream out
   output logic [31:0] tx_sample,
   input logic         tx_strobe,
   // RX Sample stream in
   input logic [31:0]  rx_sample,
   input logic         rx_strobe,
   // RX Sample stream out
   //axis_t.master axis_rx_stream
   output logic [31:0] rx_tdata_out,
   output logic        rx_tvalid_out,
   input logic         rx_tready_in,
   output logic        rx_tlast_out
   );


   always_comb begin
      if (csr_loopback_enable) begin
         // Loopback mode
//         axis_rx_stream.tdata = axis_tx_stream.tdata;
//         axis_rx_stream.tvalid = tx_strobe;
         rx_tdata_out = tx_tdata_in;
         rx_tvalid_out = tx_strobe;
      end else begin
         // Transparent pass through
//         axis_rx_stream.tdata = rx_sample;
//         axis_rx_stream.tvalid = rx_strobe;
         rx_tdata_out = rx_sample;
         rx_tvalid_out = rx_strobe;
      end // else: !if(csr_loopback_enable)

//      tx_sample = axis_tx_stream.tdata;
//      axis_rx_stream.tlast = 1'b0;
//      axis_tx_stream.tready = tx_strobe;
      tx_sample = tx_tdata_in;
      rx_tlast_out = 1'b0;
      tx_tready_out = tx_strobe;
   end // always_comb

endmodule
