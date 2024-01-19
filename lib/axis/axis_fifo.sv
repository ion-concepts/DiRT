//-------------------------------------------------------------------------------
// File:    axis_fifo.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Parameterizable:
// * Width of datapath.
// * Size (Depth) of FIFO
// * FPGA vendor
//
// Description:
// 
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`include "global_defs.svh"
// General FIFO block
//  Size == 0: Uses a single stage flop (axi_fifo_flop).
//  Size == 1: Uses a two stage flop (axi_fifo_flop2). Best choice for single stage pipelining.
//             Breaks combinatorial paths on the AXI stream data / control lines at the cost of
//             additional registers. Maps to SLICELs (i.e. does not use distributed RAM).
//  Size <= 5: Uses SRL32 to efficient maps a 32 deep FIFO to SLICEMs (axi_fifo_short). Not
//             recommended for pipelining as most devices have twice as many SLICELs as SLICEMs.
//  Size  > 5: Uses BRAM fifo (axi_fifo_bram)

module axis_fifo
  #(
    parameter WIDTH=32, 
    parameter SIZE=5, // 2^SIZE
    parameter VENDOR="xilinx",
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
    output logic [SIZE:0]      space,
    output logic [SIZE:0]      occupied);
   
  
      generate
	 if (VENDOR=="xilinx") begin
	    if(SIZE==0)
	      begin
		 //$display("unsupported config");
	      end
	    else if(SIZE<=2)
	      begin
		 // Uses flip-flops from SLICEL or SLICEM
		 axis_minimal_fifo #(.WIDTH(WIDTH)) axis_minimal_fifo_i0
		   (.clk(clk), .rst(rst),
		    .in_tdata(in_tdata), .in_tvalid(in_tvalid), .in_tready(in_tready),
                    .out_tdata(out_tdata), .out_tvalid(out_tvalid), .out_tready(out_tready),
		    .space(space), .occupied(occupied));
	      end
	    else if(SIZE<=5)
	      begin
		 logic [5:0] srl32_space;
		 logic [5:0] srl32_occupied;
		 
		 // Uses SRL32 from SLICEM (most efficient at SIZE=5)
		 axis_fifo_xilinx_srl32 #(.WIDTH(WIDTH)) axis_fifo_xilinx_srl32
		   (.clk(clk), .rst(rst),
		    .in_tdata(in_tdata), .in_tvalid(in_tvalid), .in_tready(in_tready),
		    .out_tdata(out_tdata), .out_tvalid(out_tvalid), .out_tready(out_tready),
		    .space(srl32_space), .occupied(srl32_occupied));
		 assign space = srl32_space[SIZE:0];
		 assign occupied = srl32_occupied[SIZE:0];
	      end
	    else
	      begin
		 // Uses Xilinx BRAM
		 axis_fifo_xilinx_bram #(.WIDTH(WIDTH), .SIZE(SIZE), .ULTRA(ULTRA)) fifo_bram
		   (.clk(clk), .rst(rst),
		    .in_tdata(in_tdata), .in_tvalid(in_tvalid), .in_tready(in_tready),
		    .out_tdata(out_tdata), .out_tvalid(out_tvalid), .out_tready(out_tready),
		    .space(space), .occupied(occupied));
	      end // else: !if(SIZE<=5)
	 end // if (vendor="xilinx")
	 else if  (VENDOR=="altera") begin
	    //$display("Add Altera/Intel support");
	 end
	 else
	   begin
	      //$display("Unsupported technology");
	   end
      endgenerate
   
endmodule // axis_fifo
