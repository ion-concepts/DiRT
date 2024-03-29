//-----------------------------------------------------------------------------
// File:    axis.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// Interface definition of AXI4 streaming interfaces
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`timescale 1ns/1ps

`ifndef _AXIS_SV_
 `define _AXIS_SV_

//
// Declare AXI Stream as a System Verilog interface
// (For help see Section 19 of the System Verilog Reference Manual.
//

interface axis_t
  #(parameter WIDTH = 64)
   (input clk);
   // Control flags
   bit                has_checks = 1;

   //Actual Signals
   logic [WIDTH-1:0]  tdata;
   logic              tvalid;
   logic              tready;
   logic              tlast;

   // AXIS is point-to-point,
   // declare modport for master and slave interfaces.

   modport master (output tdata, output tvalid, input tready, output tlast);
   modport slave (input tdata, input tvalid, output tready, input tlast);
   modport monitor (input tdata, input tvalid, input tready, input tlast);
                    
   //
   // Tasks for simulation use.
   //

   //
   // Write active bus beat.
   //
   task automatic write_beat;
      input logic [WIDTH-1:0] data; // Contents of tdata for this beat.
      input logic             last; // Assert tlast for this beat.

      begin
         tdata = data;
         tvalid = 1'b1;
         tlast = last;
         // Is slave ready to accept beat?
         @(posedge clk) while (~tready) @(posedge clk);
         // After accepting clock edge, de-assert ready.
         #1 tvalid = 1'b0;
      end
   endtask // insertbeat

   //
   // Read active bus beat
   //
   task automatic read_beat;
      output [WIDTH-1:0] data; // Contents of tdata for this beat.
      output logic       last; // Assert tlast for this beat.

      begin
         tready = 1'b1;

         // Is master ready with active beat?
         @(posedge clk) while (~tvalid) @(posedge clk);
         data = tdata;
         last = tlast;
         #1 tready = 1'b0;

      end
   endtask // read_beat

   //
   // Insert 1 idle master clock cycle.
   //
   task automatic idle_master;
      begin
         tdata = 'h0;
         tvalid = 1'b0;
         tlast = 1'b0;
         // One idle clock cycle
         @(posedge clk);
         #1;

      end
   endtask // idle_master

   //
   // Insert 1 idle slave clock cycle.
   //
   task automatic idle_slave;
      begin
         tready = 1'b0;
         // One idle clock cycle
         @(posedge clk);
         #1;

      end
   endtask // idle_slave

   //
   // Assertions only supported in expensive ASIC simulators!
   //


   // Assertions for generic AXIS bus faults.
   //
   /* Commented because it causes confusing verbosity with FIFO's
    who's core RAM can not be reset in simulation
   always_ff @(negedge clk) begin
      assertDataUnknown: assert property (
                                          disable iff(!has_checks)
                                          ((tvalid===1'b1) |-> $isunknown(tdata)))
        else
          $error("ERR_AXIS_DATA_XZ\n tdata went to X or Z during bus beat");

      assertLastUnknown: assert property (
                                          disable iff(!has_checks)
                                          ((tvalid===1'b1) |-> $isunknown(tlast)))
        else
          $error("ERR_AXIS_LASTXZ\n tlast went to X or Z during bus beat");
   end // always_ff @ (negedge clk)
    */

endinterface : axis_t

//----------------------------------------------------------------------
//
// Declare AXI Stream with tuser as a System Verilog interface
// (For help see Section 19 of the System Verilog Reference Manual.
//
//-----------------------------------------------------------------------

interface axis_user_t
  #(parameter WIDTH = 64, USER_WIDTH=4)
   (input clk);
   // Control flags
   bit                has_checks = 1;

   // Actual Signals
   logic [WIDTH-1:0]  tdata;
   logic              tvalid;
   logic              tready;
   logic [USER_WIDTH-1:0] tuser;
   logic                  tlast;

   // AXIS is point-to-point,
   // declare modport for master and slave interfaces.

   modport master (output tdata, output tvalid, input tready, output tuser, output tlast);
   modport slave (input tdata, input tvalid, output tready, input tuser, input tlast);
   modport monitor (input tdata, input tvalid, input tready, input tuser, input tlast);
                    
   //
   // Tasks for simulation use.
   //

   //
   // Write active bus beat.
   //
   task automatic write_beat;
      input logic [WIDTH-1:0] data; // Contents of tdata for this beat.
      input logic [USER_WIDTH-1:0] user; // Contents of tuser for this beat.     
      input logic             last; // Assert tlast for this beat.

      begin
         tdata = data;
         tuser = user;
         tvalid = 1'b1;
         tlast = last;
         // Is slave ready to accept beat?
         @(posedge clk) while (~tready) @(posedge clk);
         // After accepting clock edge, de-assert ready.
         #1 tvalid = 1'b0;
      end
   endtask // insertbeat

   //
   // Read active bus beat
   //
   task automatic read_beat;
      output [WIDTH-1:0] data; // Contents of tdata for this beat.
      output [USER_WIDTH-1:0] user; // Contents of tdata for this beat.
      output logic       last; // Assert tlast for this beat.

      begin
         tready = 1'b1;

         // Is master ready with active beat?
         @(posedge clk) while (~tvalid) @(posedge clk);
         data = tdata;
         user = tuser;
         last = tlast;
         #1 tready = 1'b0;

      end
   endtask // read_beat

   //
   // Insert 1 idle master clock cycle.
   //
   task automatic idle_master;
      begin
         tdata = 'h0;
         tuser = 'h0;
         tvalid = 1'b0;
         tlast = 1'b0;
         // One idle clock cycle
         @(posedge clk);
         #1;

      end
   endtask // idle_master

   //
   // Insert 1 idle slave clock cycle.
   //
   task automatic idle_slave;
      begin
         tready = 1'b0;
         // One idle clock cycle
         @(posedge clk);
         #1;

      end
   endtask // idle_slave

   //
   // Assertions only supported in expensive ASIC simulators!
   //


   // Assertions for generic AXIS bus faults.
   //
   always_ff @(negedge clk) begin
      assertDataUnknown: assert property (
                                          disable iff(!has_checks)
                                          ((tvalid===1'b1) |-> $isunknown(tdata)))
        else
          $error("ERR_AXIS_DATA_XZ\n tdata went to X or Z during bus beat");

      assertUserUnknown: assert property (
                                          disable iff(!has_checks)
                                          ((tvalid===1'b1) |-> $isunknown(tuser)))
        else
          $error("ERR_AXIS_USER_XZ\n tdata went to X or Z during bus beat");

      assertLastUnknown: assert property (
                                          disable iff(!has_checks)
                                          ((tvalid===1'b1) |-> $isunknown(tlast)))
        else
          $error("ERR_AXIS_LASTXZ\n tlast went to X or Z during bus beat");
   end // always_ff @ (negedge clk)


endinterface : axis_user_t


//---------------------------------------------------------------------------------
// Legacy interfaces for highly incomplete system verilog parsers
//---------------------------------------------------------------------------------
interface axis_slave_t
  #(parameter WIDTH = 64)
   (input clk);
   // Control flags
   bit                has_checks = 1;

   //Actual Signals
   logic [WIDTH-1:0]  tdata;
   logic              tvalid;
   logic              tready;
   logic              tlast;



   //
   // Tasks for simulation use.
   //


   //
   // Write active bus beat.
   //
   task automatic write_beat;
      input logic [WIDTH-1:0] data; // Contents of tdata for this beat.
      input logic             last; // Assert tlast for this beat.

      begin
         tdata = data;
         tvalid = 1'b1;
         tlast = last;
         // Is slave ready to accept beat?
         @(posedge clk) while (~tready) @(posedge clk);
         // After accepting clock edge, de-assert ready.
         #1 tvalid = 1'b0;
      end
   endtask // insertbeat


   //
   // Insert 1 idle master clock cycle.
   //
   task automatic idle_master;
      begin
         tdata = 'h0;
         tvalid = 1'b0;
         tlast = 1'b0;
         // One idle clock cycle
         @(posedge clk);
         #1;

      end
   endtask // idle_master



endinterface : axis_slave_t
//---------------------------------------------------------------------------------


interface axis_master_t
  #(parameter WIDTH = 64)
   (input clk);
   // Control flags
   bit                has_checks = 1;

   //Actual Signals
   logic [WIDTH-1:0]  tdata;
   logic              tvalid;
   logic              tready;
   logic              tlast;



   //
   // Tasks for simulation use.
   //

   //
   // Read active bus beat
   //
   task automatic read_beat;
      output [WIDTH-1:0] data; // Contents of tdata for this beat.
      output logic       last; // Assert tlast for this beat.

      begin
         tready = 1'b1;

         // Is master ready with active beat?
         @(posedge clk) while (~tvalid) @(posedge clk);
         data = tdata;
         last = tlast;
         #1;
      end
   endtask // read_beat

   //
   // Insert 1 idle slave clock cycle.
   //
   task automatic idle_slave;
      begin
         tready = 1'b0;
         // One idle clock cycle
         @(posedge clk);
         #1;
      end
   endtask // idle_slave

endinterface : axis_master_t

interface axis_broadcast_t
  #(parameter WIDTH = 64)
   (input clk);

   //Actual Signals
   logic [WIDTH-1:0]  tdata;
   logic              tvalid;
   logic              tlast;

endinterface : axis_broadcast_t


`endif //  `ifndef _AXIS_SV_


