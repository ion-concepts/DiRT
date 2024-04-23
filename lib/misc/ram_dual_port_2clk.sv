//-------------------------------------------------------------------------------
// File:    ram_dual_port_2clk.sv
//
// Author:  Ian Buckley
//
// Parameterizable:
// * Width of datapath.
// * Size (Depth) of RAM
// * Usage of output register.
//
// Description:
// Infer dual port, two clock synchronous SRAM.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------
`include "global_defs.svh"

`default_nettype none

module ram_dual_port_2clk
  #(
    parameter WIDTH=32,
    parameter SIZE=9, // Xilinx BRAM is 512x36
    parameter ULTRA=0,
    parameter OUTPUT_REGISTER=0
    )
   (
    input wire               clk1,
    input wire               enable1,
    input wire               write1,
    input wire [SIZE-1:0]    addr1,
    input wire [WIDTH-1:0]   data_in1,
    output logic [WIDTH-1:0] data_out1,

    input wire               clk2,
    input wire               enable2,
    input wire               write2,
    input wire [SIZE-1:0]    addr2,
    input wire [WIDTH-1:0]   data_in2,
    output logic [WIDTH-1:0] data_out2
    );

   localparam               RAMSIZE = 1 << SIZE;

   logic [WIDTH-1:0]        dout1;
   logic [WIDTH-1:0]        dout2;

   if (OUTPUT_REGISTER) begin: output_register
      always_ff @(posedge clk1) begin
         if (enable1) data_out1 <= dout1;
      end

      always_ff @(posedge clk2) begin
         if (enable2) data_out2 <= dout2;
      end
   end: output_register
   else begin: no_output_register
      always_comb begin
         data_out1 = dout1;
         data_out2 = dout2;
      end
   end: no_output_register

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
              dout1 <= ram[addr1];
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
              dout2 <= ram[addr2];
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
                dout1 <= ram[addr1];
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
                dout2 <= ram[addr2];
             end
        end
     end: normal
endmodule // ram_dual_port_2clk

`default_nettype wire
