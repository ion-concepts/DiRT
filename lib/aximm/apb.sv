//-----------------------------------------------------------------------------
// File:    apb.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// Interface definition of APB interface modeled after Pulp AXI interfaces.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------

`ifndef _APB_SV_
 `define _APB_SV_

// An APB interface.
interface APB 
  #(
    parameter int unsigned AXI_ADDR_WIDTH = 0,
    parameter int unsigned AXI_DATA_WIDTH = 0
    );

   localparam int unsigned AXI_STRB_WIDTH = AXI_DATA_WIDTH / 8;

   typedef logic [AXI_ADDR_WIDTH-1:0] addr_t;
   typedef logic [AXI_DATA_WIDTH-1:0] data_t;
   typedef logic [AXI_STRB_WIDTH-1:0] strb_t;
   typedef logic [2:0]                prot_t;
   

   addr_t          p_addr;
   logic           p_enable;  
   prot_t          p_prot;
   data_t          p_rdata;
   logic           p_ready;
   logic           p_sel;
   logic           p_slverr;
   strb_t          p_strb;
   data_t          p_wdata;
   logic           p_write;

   

  modport Master 
    (
     output p_addr, output p_enable, output p_prot, 
     input  p_rdata, input p_ready,
     output p_sel, input p_slverr, output p_strb,
     output p_wdata, output p_write
  );

   modport Slave
    (
     input  p_addr,input p_enable, input p_prot, 
     output p_rdata, output p_ready,
     input  p_sel, output p_slverr, input p_strb,
     input p_wdata, input p_write
  );

   modport Monitor
     (
      input p_addr,input p_enable, input p_prot, 
      input p_rdata, input p_ready,
      input p_sel, input p_slverr, input p_strb,
      input p_wdata, input p_write
  );
   
endinterface

`endif //  `ifndef _APB_SV_
