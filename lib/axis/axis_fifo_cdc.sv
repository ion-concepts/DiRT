//-------------------------------------------------------------------------------
// File:    axis_fifo_cdc.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Width of datapath.
// * Size (Depth) of FIFO
// * FPGA vendor
//
// Description:
// Clock domain crossing (CDC) FIFO.
// Can use vendor hard RAM or soft RAM.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------


`include "global_defs.svh"

module axis_fifo_cdc
  #(
    parameter WIDTH=32, 
    parameter SIZE=9,
    parameter VENDOR="xilinx"
    )
    (
     input logic 	      rst,
     // Signals on input clock domain
     input logic 	      in_clk,
     input logic [WIDTH-1:0]  in_tdata,
     input logic 	      in_tvalid,
     output logic 	      in_tready,
     // Signals on output clock domain
     input logic 	      out_clk,
     output logic [WIDTH-1:0] out_tdata,
     output logic 	      out_tvalid,
     input logic 	      out_tready
     );
   
   wire 		      write;
   wire 		      read;
   wire 		      empty;
   wire 		      full;
   wire [WIDTH-1:0] 	      tdata_int;
   wire 		      tvalid_int;
   wire 		      tready_int;
   wire [WIDTH-1:0] 	      wr_data;
   wire [WIDTH-1:0] 	      rd_data;
   
   assign in_tready = ~full;
   assign write = in_tvalid & in_tready;

   assign tvalid_int = ~empty;
   assign read = tvalid_int & tready_int;

   assign wr_data[WIDTH-1:0] = in_tdata;
   assign tdata_int = rd_data[WIDTH-1:0];
   //
   // Choose between distributed RAM or BRAM for CDC element.
   //
   generate
      // Distributed RAM based.
      if(SIZE<=5)
	fifo_short_2clk fifo_short_2clk
	  (
	   .rst(rst),
	   .wr_clk(in_clk),
	   .din(wr_data),
	   .wr_en(write),
	   .full(full),
	   .wr_data_count(),
	  
	   .rd_clk(out_clk),
	   .dout(rd_data),
	   .rd_en(read),
	   .empty(empty),
	   .rd_data_count()
	   );
      else
	// BRAM based
	fifo_4k_2clk fifo_4k_2clk
	  (
	   .rst(rst),
	   .wr_clk(in_clk),
	   .din(wr_data),
	   .wr_en(write),
	   .full(full),
	   .wr_data_count(),
	  
	   .rd_clk(out_clk),
	   .dout(rd_data),
	   .rd_en(read),
	   .empty(empty),
	   .rd_data_count()
	   );
   endgenerate
   //
   // Only need to use a single actual 2 clock FIFO to bridge clock domain
   // so top up remaining cpacity required with single clock FIFO.
   //
   generate
      if(SIZE>9)
	axis_fifo #(
		    .WIDTH(WIDTH), 
		    .SIZE(SIZE),
		    .VENDOR(VENDOR)
		    ) fifo_1clk
	  (
	   .clk(out_clk), .rst(rst), .clear(1'b0),
	   .in_tdata(tdata_int), .in_tvalid(tvalid_int), .in_tready(tready_int),
	   .out_tdata(out_tdata), .out_tvalid(out_tvalid), .out_tready(out_tready),
	   .space(), .occupied());
      else
	begin
	   assign out_tdata = tdata_int;
	   assign out_tvalid = tvalid_int;
	   assign tready_int = out_tready;
	end
   endgenerate
   
endmodule // axis_fifo_cdc
