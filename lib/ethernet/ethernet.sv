//-----------------------------------------------------------------------------
// File:    ethernet.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// Interface definitions of standardized ethernet busses
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`timescale 1ns/1ps
  
`ifndef _ETHERNET_SV_
 `define _ETHERNET_SV_

//
// Declare GMII as a System Verilog interface
// (For help see Section 19 of the System Verilog Reference Manual.
// (Gigabit signals only)
//
interface gmii_t
   #(parameter WIDTH = 8);
   
   logic             txclk;
   logic [WIDTH-1:0] txd;
   logic             txen;
   logic             txer;
   logic             rxclk;
   logic [WIDTH-1:0] rxd;
   logic             rxdv;
   logic             rxer;
   logic             col;
   logic             cs;

   modport mac (output txclk, output txd, output txen, output txer,
                input rxclk, input rxd, input rxdv,
                input rxer, input col, input cs);

   modport phy (input txclk, input txd, input txen, input txer,
                output rxclk, output rxd, output rxdv,
                output rxer, output col, output cs);

   modport monitor (input txclk, input txd, input txen, input txer,
                input rxclk, input rxd, input rxdv,
                input rxer, input col, input cs);
  
endinterface : gmii_t


//
// Declare MDIO as a System Verilog interface
// (For help see Section 19 of the System Verilog Reference Manual.
// MDIO is at a PCB level a 2 wire tristate bus, but inside an
// ASIC/FPGA its a 3 wire unidirectional interface often with a tristate
// control line that can be used to control a driver to make a PCB tristate bus.
//
interface mdio_t;
   
   logic mdc;
   logic mdi;
   logic mdo;
   logic mdt;

   modport mac (output mdc, output mdo, input mdi, output mdt);
   modport phy (input mdc, input mdo, output mdi, input mdt);
   modport monitor (input mdc, input mdo, input mdi, input mdt);
   

 
endinterface : mdio_t


`endif //  `ifndef _ETHERNET_SV_
