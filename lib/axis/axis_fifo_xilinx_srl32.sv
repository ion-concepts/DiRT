//-------------------------------------------------------------------------------
// File:    axis_fifo_xilinx_srl32.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Parameterizable:
// * Width of datapath.
//
// Description:
// This module uses the SRLC32E primitive explicitly and thus the oldest Xilinx device
// support is VIRTEX-6/SPARTAN-6
// SIZE is fixed at 5
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_fifo_xilinx_srl32
  #(parameter WIDTH=32)
   (
    input logic 	     clk, 
    input logic 	     rst, 
    input logic [WIDTH-1:0]  in_tdata,
    input logic 	     in_tvalid,
    output logic 	     in_tready,
    output logic [WIDTH-1:0] out_tdata,
    output logic 	     out_tvalid,
    input logic 	     out_tready,

   
    output reg [5:0] 	     space,
    output reg [5:0] 	     occupied
    );

   reg 		     full = 1'b0;
   reg 		     empty = 1'b1;
   logic 	     write;
   logic 	     read;
   
   assign write = in_tvalid & in_tready;
   assign read = out_tready & out_tvalid;

   assign in_tready  = ~full;
   assign out_tvalid  = ~empty;
   
   reg [4:0]      addr;
   genvar         i; 
   
   generate
      for (i=0;i<WIDTH;i=i+1)
        begin : gen_srlc32e
           SRLC32E
             srlc32e(.Q(out_tdata[i]), .Q31(),
                     .A(addr),
                    .CE(write),.CLK(clk),.D(in_tdata[i]));
        end
   endgenerate
   
   always_ff @(posedge clk)
     if(rst)
       begin
          addr <= 0;
          empty <= 1;
          full <= 0;
       end
     else if(read & ~write)
       begin
          full <= 0;
          if(addr==0)
            empty <= 1;
          else
            addr <= addr - 1;
       end
     else if(write & ~read)
       begin
          empty <= 0;
          if(~empty)
            addr <= addr + 1;
          if(addr == 30)
            full <= 1;
       end

  
   always_ff @(posedge clk)
     if(rst)
       space <= 6'd32;
     else if(read & ~write)
       space <= space + 6'd1;
     else if(write & ~read)
       space <= space - 6'd1;
   
   always_ff @(posedge clk)
     if(rst)
       occupied <= 6'd0;
     else if(read & ~write)
       occupied <= occupied - 6'd1;
     else if(write & ~read)
       occupied <= occupied + 6'd1;
      
endmodule // axis_fifo_xilinx_srl32
