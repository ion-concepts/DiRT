//-------------------------------------------------------------------------------
// File:    axis_fifo_xilinx_bram.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Width of datapath.
// * Size (Depth) of FIFO
//
// Description:
//
//  License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_fifo_xilinx_bram
  #(
    parameter WIDTH=32,
    parameter SIZE=9,
    parameter ULTRA=0
    )
   (
    input logic 	     clk,
    input logic 	     rst,
    // Input Bus
    input logic [WIDTH-1:0]  in_tdata,
    input logic 	     in_tvalid,
    output logic 	     in_tready,
    // Output bus
    output logic [WIDTH-1:0] out_tdata,
    output logic 	     out_tvalid,
    input logic 	     out_tready,
    // Debug
    output reg [SIZE:0] 	     space,
    output reg [SIZE:0] 	     occupied
    );


   logic 			     write;
   logic 			     read;

   //
   // Read state machine
   //
   logic [1:0]                       read_state;
   localparam 	  EMPTY = 0;
   localparam 	  PRE_READ = 1;
   localparam 	  READING = 2;

   logic [SIZE-1:0] wr_addr;
   logic [SIZE-1:0] rd_addr;

   logic            empty;
   logic            full;

   assign  write 	     = in_tvalid & in_tready;
   assign  read 	     = out_tvalid & out_tready;
   assign in_tready  = ~full;
   assign out_tvalid  = ~empty;

   always_ff @(posedge clk)
     if (rst)
       wr_addr <= 0;
   else if (write)
     wr_addr <= wr_addr + 1;

   // Use infered RAM rather than tech specific library cell for now.
   ram_dual_port_2clk #(.WIDTH(WIDTH),.SIZE(SIZE),.ULTRA(ULTRA)) ram
     (
      .clk1(clk),
      .enable1(1'b1),
      .write1(write),
      .addr1(wr_addr),
      .data_in1(in_tdata),
      .data_out1(),

      .clk2(clk),
      .enable2((read_state==PRE_READ)|read),
      .write2(1'b0),
      .addr2(rd_addr),
      .data_in2({WIDTH{1'b1}}),
      .data_out2(out_tdata)
      );

   always_ff @(posedge clk)
     if(rst)
       begin
	  read_state <= EMPTY;
	  rd_addr <= 0;
	  empty <= 1;
       end
     else
       case(read_state)
	 EMPTY :
	   if(write)
	     begin
		read_state <= PRE_READ;
	     end
	 PRE_READ :
	   begin
	      read_state <= READING;
	      empty <= 0;
	      rd_addr <= rd_addr + 1;
	   end

	 READING :
	   if(read)
	     if(rd_addr == wr_addr)
	       begin
		  empty <= 1;
		  if(write)
		    read_state <= PRE_READ;
		  else
		    read_state <= EMPTY;
	       end
	     else
	       rd_addr <= rd_addr + 1;
       endcase // case(read_state)

   logic [SIZE-1:0] dont_write_past_me;
   logic 	    becoming_full;

   always_comb begin
      dont_write_past_me = rd_addr - 2;
      becoming_full = wr_addr == dont_write_past_me;
   end

   always_ff @(posedge clk)
     if(rst)
       full <= 0;
     else if(read & ~write)
       full <= 0;
     else if(write & ~read & becoming_full)
       full <= 1;

   localparam NUMLINES = (1<<SIZE);
   always_ff @(posedge clk)
     if(rst)
       space <= NUMLINES;
     else if(read & ~write)
       space <= space + 1'b1;
     else if(write & ~read)
       space <= space - 1'b1;

   always_ff @(posedge clk)
     if(rst)
       occupied <= 16'b0;
     else if(read & ~write)
       occupied <= occupied - 1'b1;
     else if(write & ~read)
       occupied <= occupied + 1'b1;


endmodule // axis_fifo_xilinx_bram
