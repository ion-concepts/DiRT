//-------------------------------------------------------------------------------
// File:    protocol.vh
//
// Author:  Ian Buckley
//
// Description:
// Library of simple precompiler macro's for legacy Verilog code that can not use System Verilog equivalents
// Facilitates packet aware manipulation of axis buses.
//
//
//-----------------------------------------------------------------------------



`ifndef _PROTOCOL_VH_
 `define _PROTOCOL_VH_
// Packet Types.
 `define   INT16_COMPLEX 8'h00,    //Integer complex numbers in a 16bit format. Used for example for IQ sample data.
 `define   INT16_REAL 8'h01,       //Integer real numbers in a 16bit format. Used for example, for real valued sample data.
           //  INT12_COMPLEX,      //Integer complex numbers in a 12bit (packed) format. Used for example for IQ sample data.
           //  INT12_REAL,         //Integer real numbers in a 12bit (packed) format. Used for example for IQ sample data
 `define   FLOAT32_COMPLEX 8'h02,  //Float complex numbers in an IEEE 32bit format. Used for example for IQ sample data
 `define   FLOAT32_REAL 8'h03,     //Float real numbers in an IEEE 32bit format. Used for example for IQ sample data
 `define   WRITE_MM32 8'h80,       //Create single 32bit memory mapped write transaction (single beat - no burst).
 `define   READ_MM32 8'h81,	   //Create single 32bit memory mapped read transaction (single beat - no burst).
 `define   WRITE_MM16 8'h82,	   //Create single 16bit memory mapped write transaction (single beat - no burst).
 `define   READ_MM16 8'h83,	   //Create single 16bit memory mapped read transaction (single beat - no burst).
 `define   WRITE_MM8 8'h84,	   //Create single 8bit memory mapped write transaction (single beat - no burst).
 `define   READ_MM8 8'h85,	   //Create single 8bit memory mapped read transaction (single beat - no burst).
 `define   STATUS 8'hC0,	   //Provides "execution" status for other packets back towards host
 `define   FLOW_CREDIT 8'hC1,	   //Returns flow control credit back to source from sink.
 `define   STRUCTURED 8'hFF

// Packet Header FIelds
 `define PKT_TYPE(x) x[63:56]
 `define PKT_SEQID(x) x[55:48]
 `define PKT_SIZE(x) x[47:32]
 `define PKT_SIZE_BEATS(x) x[47:35]
 `define PKT_FLOWID(x) x[31:0]
 `define PKT_SRC(x) x[31:16]
 `define PKT_DST(x) x[15:0]


`endif

