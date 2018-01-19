//-------------------------------------------------------------------------------
//-- File:    axis_fifo_xilinx_srl32.sv
//--
//-- Author:  Ian Buckley
//--
//-- Parameterizable:
//-- * Width of datapath.
//--
//-- Description:
//-- This module uses the SRLC32E primitive explicitly and thus the oldest Xilinx device
//-- support is VIRTEX-6/SPARTAN-6
//-- SIZE is fixed at 5
//--
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module axis_fifo_xilinx_srl32
  #(parameter WIDTH=32)
   (
    input logic 	     clk, 
    input logic 	     rst, 
    input logic [WIDTH-1:0]  i_tdata,
    input logic 	     i_tvalid,
    output logic 	     i_tready,
    output logic [WIDTH-1:0] o_tdata,
    output logic 	     o_tvalid,
    input logic 	     o_tready,

   
    output reg [5:0] 	     space,
    output reg [5:0] 	     occupied
    );

   reg 		     full = 1'b0;
   reg 		     empty = 1'b1;
   logic write        = i_tvalid & i_tready;
   logic read         = o_tready & o_tvalid;

   assign i_tready  = ~full;
   assign o_tvalid  = ~empty;
   
   reg [4:0]      addr;
   genvar         i; 
   
   generate
      for (i=0;i<WIDTH;i=i+1)
        begin : gen_srlc32e
           SRLC32E
             srlc32e(.Q(o_tdata[i]), .Q31(),
                     .A(addr),
                    .CE(write),.CLK(clk),.D(i_tdata[i]));
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
