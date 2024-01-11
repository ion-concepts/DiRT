//-------------------------------------------------------------------------------
// File:    ram_dual_port_2clk.sv
//
// Author:  Ian Buckley
//
// Parameterizable:
// * Width of datapath.
// * Size (Depth) of RAM
//
// Description:
// Infer dual port, two clock synchronous SRAM.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

module ram_dual_port_2clk
  #(
    parameter WIDTH=32,
    parameter SIZE=9, // Xilinx BRAM is 512x36
    parameter ULTRA=0
    ) 
   (
    input logic             clk1,
    input logic             enable1,
    input logic             write1,
    input logic [SIZE-1:0]  addr1,
    input logic [WIDTH-1:0] data_in1,
    output reg [WIDTH-1:0]  data_out1,
   
    input logic             clk2,
    input logic             enable2,
    input logic             write2,
    input logic [SIZE-1:0]  addr2,
    input logic [WIDTH-1:0] data_in2,
    output reg [WIDTH-1:0]  data_out2
    );
   
   localparam               RAMSIZE = 1 << SIZE;

   if (ULTRA == 1) begin: ultra
      (* ram_style = "ultra" *)  reg [WIDTH-1:0] ram [RAMSIZE-1:0];
      //
      // Port1
      //
      always @(posedge clk1) begin
         if (enable1)
           begin
              if (write1)
                ram[addr1] <= data_in1;
              data_out1 <= ram[addr1];
           end
      end

      //
      // Port2
      //
      always @(posedge clk2) begin
         if (enable2)
           begin
              if (write2)
                ram[addr2] <= data_in2;
              data_out2 <= ram[addr2];
           end
      end
   end: ultra
   else
     begin: normal
        reg [WIDTH-1:0] ram [RAMSIZE-1:0];

        //
        // Port1
        //
        always @(posedge clk1) begin
           if (enable1)
             begin
                if (write1)
                  ram[addr1] <= data_in1;
                data_out1 <= ram[addr1];
             end
        end

        //
        // Port2
        //
        always @(posedge clk2) begin
           if (enable2)
             begin
                if (write2)
                  ram[addr2] <= data_in2;
                data_out2 <= ram[addr2];
             end
        end
     end: normal
endmodule // ram_dual_port_2clk
