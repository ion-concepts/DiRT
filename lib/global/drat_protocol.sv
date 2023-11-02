//-------------------------------------------------------------------------------
// File:    drat_protocol.sv
//
// Author:  Ian Buckley, Ion Concepts LLC
//
// Description:
// Library of tasks to assist simulations of packet traffic over axis buses.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-------------------------------------------------------------------------------

`ifndef _DRAT_PROTOCOL_SV_
 `define _DRAT_PROTOCOL_SV_

// Pull in AXI Streaming libarary.
`ifndef _AXIS_SV_
 `include "axis.sv"
`endif

// Relies on SVUnit
`include "svunit_defines.svh"

package drat_protocol;
   import svunit_pkg::*;
   
// Make the math trivial to calculate bytes from beats.
   
// (xsim in 2022.2 does not support 'let')
 let beats_to_bytes(x) = (x)*8;
 let bytes_to_beats(x) = (((x)+7)>>3);


// Enumerate the various defined packet types
typedef enum logic [7:0]
  {
   // Integer complex numbers in a 16bit format.
   INT16_COMPLEX=8'h00,    
   // Integer complex numbers in a 16bit format. Marks end of burst.
   INT16_COMPLEX_EOB=8'h10,  
   // Integer complex numbers in a 16bit format. Timestamp unused.
   INT16_COMPLEX_ASYNC=8'h20,  
   // Integer complex numbers in a 16bit format. Timestamp unused. Marks end of burst.
   INT16_COMPLEX_ASYNC_EOB=8'h30,
   // Integer real numbers in a 16bit format. Used for example, for real valued sample data.
   INT16_REAL=8'h01,     
   // Integer complex numbers in a 12bit (packed) format. Used for example for IQ sample data.
   //  INT12_COMPLEX,      
   // Integer real numbers in a 12bit (packed) format. Used for example for IQ sample data
   //  INT12_REAL,      
   // Float complex numbers in an IEEE 32bit format. Used for example for IQ sample data
   FLOAT32_COMPLEX=8'h02, 
   // Float real numbers in an IEEE 32bit format. Used for example for IQ sample data
   FLOAT32_REAL=8'h03, 
   // Integer complex numbers in a 16 vectors of 16bit format.
   INT16x16_COMPLEX=8'h08,  
   // Integer complex numbers in a 16 vectors of 16bit format. Marks end of burst.
   INT16x16_COMPLEX_EOB=8'h18, 
   // Integer complex numbers in a 16 vectors of 16bit format. Timestamp unused.
   INT16x16_COMPLEX_ASYNC=8'h28,
   // Integer complex numbers in a 16 vectors of 16bit format. Timestamp unused. Marks end of burst.
   INT16x16_COMPLEX_ASYNC_EOB=8'h38,
   // 2bit coded integer in PPRX specific packed format.
   PPRX2_REAL=8'h09,
   // 2bit coded integer in PPRX specific packed format.
   PPRX2_REAL_EOB=8'h19,
   // Create single 32bit memory mapped write transaction (single beat - no burst).
   WRITE_MM32=8'h80,   
   // Create single 32bit memory mapped read transaction (single beat - no burst).
   READ_MM32=8'h81,
   // Response packet for 32bit memory mapped read transaction
   RESPONSE_MM32=8'h86, 
   // Create single 16bit memory mapped write transaction (single beat - no burst).
   WRITE_MM16=8'h82,
   // Create single 16bit memory mapped read transaction (single beat - no burst).
   READ_MM16=8'h83,
   // Response packet for 16bit memory mapped read transaction
   RESPONSE_MM16=8'h87, 
   // Create single 8bit memory mapped write transaction (single beat - no burst).
   WRITE_MM8=8'h84,	
   // Create single 8bit memory mapped read transaction (single beat - no burst).
   READ_MM8=8'h85,	  
   // Response packet for 8bit memory mapped read transaction
   RESPONSE_MM8=8'h88,  
   // Provides "execution" status for other packets back towards host
   STATUS=8'hC0,
  
   // Provides a report of the current System Time
   TIME_REPORT=8'hC1,
   STRUCTURED=8'hFF
   } pkt_type_t;

typedef enum logic [31:0]
  {
   ACK=32'h0,
   EOB_ACK=32'h1,
   UNDERFLOW=32'h2,
   SEQ_ERROR_START=32'h4,
   SEQ_ERROR_MID=32'h8,
   LATE=32'h10
   } status_type_t;

// enumerated addresses of flow src/sinks for test bench readability
typedef enum logic [15:0]
             {
              SRC0,
              SRC1,
              SRC2,
              SRC3
              } node_src_addr_t;
   
// enumerated addresses of flow src/sinks for test bench readability
typedef enum logic [15:0]
             {
              DST0,
              DST1,
              DST2,
              DST3
              } node_dst_addr_t;

// Define a source / dest pairing of addresses to define a flow.
typedef struct packed
               {
                  node_src_addr_t flow_src;
                  node_dst_addr_t flow_dst;
               } flow_addr_t;

// flow_id can be thought of as a unique identifier for the flow
// or a source/sink address pairing
typedef union packed
              {
                 logic [31:0] flow_id;
                 flow_addr_t flow_addr;
              } flow_id_t;

// Full packet header definition
typedef struct packed
               {
                  pkt_type_t packet_type;
                  logic [7:0]  seq_id;
                  logic [15:0] length;
                  flow_id_t flow_id;
                  logic [63:0] timestamp;
               } pkt_header_t;
    
// Individual payload beat for INT16_COMPLEX_[EOB|ASYNC|ASYNC_EOB]
typedef struct packed
               {
                  logic [15:0] i0;
                  logic [15:0] q0;
                  logic [15:0] i1;
                  logic [15:0] q1;
               } int16_complex_t;

// Payload beat for STATUS packet.
typedef struct packed
               {
                  status_type_t status_type;
                  logic [23:0] padding;
                  logic [7:0]  seq_id;
               }  status_beat_t;

// Generic payload beat.
typedef union packed
              {
                 logic [63:0] beat;
                 int16_complex_t int16_complex;
                 status_beat_t status_beat;
              } payload_beat_t;


// Payload is composed of variable number of beats after header
typedef payload_beat_t pkt_payload_t [];

// NOTE: Can't build a struct containing a pkt_header_t and pkt_payload_t because
// its illegal to have packed structs mixed with dynamic arrays.


//-------------------------------------------------------------------------------
//-- Given a packet header structure, expand into vectors of bits.
//-------------------------------------------------------------------------------
function logic [63:0] extract_header (input pkt_header_t header);
   return {header.packet_type, header.seq_id, header.length, header.flow_id};
endfunction : extract_header

function logic [63:0] extract_timestamp (input pkt_header_t header);
   return {header.timestamp};
endfunction : extract_timestamp

//-------------------------------------------------------------------------------
//-- Given two vectors of bits (Beats of a packet), populate a header data structure.
//-- returns pkt_header_t
//-------------------------------------------------------------------------------
function pkt_header_t populate_header (input logic [127:0] header_beats);
   pkt_header_t header;
   header = '{
              packet_type:pkt_type_t'(header_beats[127:120]),
              seq_id:header_beats[119:112],
              length:header_beats[111:96],
              flow_id:header_beats[95:64],
              timestamp:header_beats[63:0]
              };
   return header;
endfunction : populate_header

//-------------------------------------------------------------------------------
//-- Given only the first beat of a packet, populate a header data structure.
//-- returns pkt_header_t with timestamp = 0
//-------------------------------------------------------------------------------
function pkt_header_t populate_header_no_timestamp (input logic [63:0] header_beat);
    return populate_header({header_beat, 64'b0});
endfunction // populate_header_no_timestamp

//-------------------------------------------------------------------------------
//-- Given a payload beat of an INT16_COMPLEX* packet, populate a payload beat structure
//-- returns payload_beat_t
//-------------------------------------------------------------------------------
function payload_beat_t populate_int16_complex_beat (input logic [63:0] header_beat);
    payload_beat_t beat;   
    beat.int16_complex.i0 = header_beat[63:48];
    beat.int16_complex.q0 = header_beat[47:32];
    beat.int16_complex.i1 = header_beat[31:16];
    beat.int16_complex.q1 = header_beat[15:0];    
    return beat;
endfunction : populate_int16_complex_beat
    
//-------------------------------------------------------------------------------
//-- Compare two header structures, return 1 if equal, 0 otherwise.
//-------------------------------------------------------------------------------
function logic header_compare(input pkt_header_t a, input pkt_header_t b);
  return ((a.packet_type === b.packet_type) &&
          (a.seq_id === b.seq_id) &&
          (a.length === b.length) &&
          (a.flow_id === b.flow_id) &&
          (a.timestamp == b.timestamp));
endfunction : header_compare

//-------------------------------------------------------------------------------
//-- Compare two payload arrays, return 1 if equal, 0 otherwise.
//-------------------------------------------------------------------------------
function logic payload_compare(input pkt_payload_t a, input pkt_payload_t b);
    if (a.size() !== b.size()) begin
        return (0);
    end

    for (integer i = 0; i < a.size(); i++ ) begin
        if (a[i] !== b[i]) begin
            return (0);
        end
    end
    return(1);
endfunction



//-------------------------------------------------------------------------------
//-- Print Header
//-------------------------------------------------------------------------------
function void print_header(input pkt_header_t header);
   $display("Type:   %s", header.packet_type.name);
   $display("SeqID:  %0d", header.seq_id);
   $display("Length: %0d", header.length);
   $display("FlowID: %s -> %s", header.flow_id.flow_addr.flow_src.name,header.flow_id.flow_addr.flow_dst.name);
   $display("Time:   %0d", header.timestamp);
endfunction : print_header

// Object to generate random payloads for packets.
/* -----\/----- EXCLUDED -----\/-----
class RandomPayload;
   pkt_payload_t payload;
   rand shortint unsigned len;
   constraint len_c { len inside {[3:65535]};  }

   function void post_randomize;
      payload = new[this.len];
      foreach (payload [i])
        payload[i] = $urandom;

      $display ("%p", this);
      $display ("payload.size: %0d", payload.size);
   endfunction : post_randomize
endclass : RandomPayload
 -----/\----- EXCLUDED -----/\----- */

//
// Generic DRaT Packet type.
// Provides general packet manipulation and low level test functions.
// Designed for inhertance to support specific packet formats.
//
class DRaTPacket;
   protected pkt_header_t header;
   protected pkt_payload_t payload;
   local int next;
   local logic [15:0] count;

   // Provide explicit initialization
   function new;
      this.init;
   endfunction : new

   // Provide explicit initialization
   function void init;
      header.packet_type = INT16_COMPLEX;
      header.seq_id = 0;
      header.length = 8; // Illegal as-is, needs non zero payload.
      header.flow_id.flow_id = 0;
      header.timestamp = 0;
   endfunction : init

   // Return packet payload to minimal initialized state.
   function void reset_payload(integer len=1);
      this.payload=new[len];
   endfunction : reset_payload

   // Set length of packet (in bytes)
   function void set_length(shortint length);
      this.header.length = length;
   endfunction: set_length

   // Returns confgured length of packet (in bytes)
   function shortint get_length();
      return(this.header.length);
   endfunction : get_length

   // Set sequence ID of packet
   function void set_seq_id(bit [7:0] seq_id);
      this.header.seq_id = seq_id;
   endfunction: set_seq_id

   // Returns sequence ID of packet
   function bit [7:0] get_seq_id();
      return(this.header.seq_id);
   endfunction : get_seq_id

   // Increment sequence ID of packet modulo 256
   function void inc_seq_id();
      this.header.seq_id =  this.header.seq_id + 8'd1;
   endfunction : inc_seq_id

   // Set the flow ID
   function void set_flow_id(flow_id_t flow_id);
      this.header.flow_id = flow_id;
   endfunction : set_flow_id

   // Get the flow ID
   function flow_id_t get_flow_id();
      return(this.header.flow_id);
   endfunction : get_flow_id

   // Set Source of this packet
   function void set_flow_src(node_src_addr_t node_addr);
      this.header.flow_id.flow_addr.flow_src = node_addr;
   endfunction : set_flow_src

   // Set Destination of this packet
   function void set_flow_dst(node_dst_addr_t node_addr);
      this.header.flow_id.flow_addr.flow_dst = node_addr;
   endfunction : set_flow_dst

   // Set Packet Type
   function void set_packet_type(pkt_type_t packet_type);
      this.header.packet_type = packet_type;
   endfunction : set_packet_type

   // Get Packet Type
   function pkt_type_t get_packet_type();
      return(this.header.packet_type);
   endfunction : get_packet_type

   // Set header field from raw bit vector
   function void set_raw_header(bit [63:0] raw_header);
      // Explicit cast required to override ENUM strong typing
      this.header.packet_type = pkt_type_t'(raw_header[63:56]);
      this.header.seq_id = raw_header[55:48];
      this.header.length = raw_header[47:32];
      this.header.flow_id = raw_header[31:0];
   endfunction :set_raw_header

   // Get first line of header as bit vector
   function bit [63:0] get_raw_header();
      return(extract_header(this.header));
   endfunction : get_raw_header

   // Set Timestamp
   function void set_timestamp(bit [63:0] timestamp);
      this.header.timestamp = timestamp;
   endfunction : set_timestamp

   // Get second line of header as bit vector
   function bit [63:0] get_timestamp();
      return(extract_timestamp(this.header));
   endfunction : get_timestamp

   // Get second line of header as bit vector
   function void update_timestamp(bit [63:0] increment);
      this.header.timestamp =  this.header.timestamp + increment;
   endfunction : update_timestamp

   // Set entire header using packed structure
   function void set_header(pkt_header_t header);
      this.header = header;
   endfunction : set_header

   // Return entire header as structure
   function pkt_header_t get_header();
      return(this.header);
   endfunction : get_header

   // Return entire payload as array
   function pkt_payload_t get_payload();
      return(this.payload);
   endfunction : get_payload

   // Packets payload is already allocated.
   // Add beat to packet using
   // private index pointer
   function void set_beat(bit [63:0] beat);
      this.payload[next] = beat;
      next = next + 1;
   endfunction : set_beat

   // Return next payload beat
   function bit [63:0] get_beat();
      next = next + 1;
      return(this.payload[next-1]);
   endfunction : get_beat

   // Add a new beat to end of current payload.
   // Adjust header to match and allocate extra storage.
   // Assumes payload always has full beats. (length%8=0)
   function void add_beat(bit [63:0] beat);
      this.header.length = this.header.length + 8;
      payload = new[bytes_to_beats(this.header.length-16)] (payload);
      payload[(this.header.length-24)>>3] = beat;
   endfunction : add_beat

   // Add beat to end of packet without being protocol aware.
   // Allocate additional storage.
   // (i.e we don't look at or change the header)
   function void add_beat_raw(bit [63:0] beat);
      payload = new[this.payload.size()+1] (payload);
      payload[this.payload.size()-1] = beat;
   endfunction : add_beat_raw

   // Reset payload pointer back to start.
   function void rewind_payload();
      next = 0;
   endfunction : rewind_payload

   // Get status field from STATUS packet
   function status_type_t get_status_type();
      return(this.payload[0].status_beat.status_type);
   endfunction : get_status_type

   // Get actual SeqID field from STATUS packet payload
   function bit [7:0] get_status_seq_id();
      return(this.payload[0].status_beat.seq_id);
   endfunction : get_status_seq_id

   // Generate a random payload of length determined by header
   // (Note size in header is in bytes and includes the header.
   function void random();
      payload = new[bytes_to_beats(this.header.length-16)];
      foreach (payload [i])
        payload[i] = {$random,$random};
   endfunction : random

   // Generate a 16bit ramp inside payload of length determined by header
   // (Note size in header is in bytes and includes the header.
   // Last beat will always have ramp data in all 16bit fields even if packet is shorter.
   // I & Q have same data.
   function void ramp(logic reset_count=1);
      payload = new[bytes_to_beats(this.header.length-16)];
      if (reset_count) begin
          count = 0;
      end
      foreach (payload [i]) begin
         payload[i] = count << 48 |
                      (count+1) << 32 |
                      (count+2) << 16 |
                      (count+3);
         count = count + 4;
      end
   endfunction : ramp

   // Verification function for STATUS format packets
 //  function void assert_status_packet(
   task assert_status_packet(
                                      bit [7:0] seq_id,
                                      bit [15:0] length,
                                      flow_id_t flow_id,
                                      bit [63:0] timestamp=0,
                                      bit [63:0] timestamp_min=0,
                                      bit [63:0] timestamp_max=0,
                                      status_type_t status_type,
                                      bit [7:0] status_seq_id
                                      );
       `FAIL_UNLESS_EQUAL(this.get_packet_type() , STATUS);
       `FAIL_UNLESS_EQUAL(this.get_seq_id() , seq_id)
       `FAIL_UNLESS_EQUAL(this.get_length() , length);
       `FAIL_UNLESS_EQUAL(this.get_flow_id() , flow_id);
       if (timestamp != 0) `FAIL_UNLESS_EQUAL(this.get_timestamp(), timestamp);
       if (timestamp_min != 0) `FAIL_UNLESS(this.get_timestamp() > timestamp_min);
       if (timestamp_max != 0) `FAIL_UNLESS(this.get_timestamp() < timestamp_max);
       `FAIL_UNLESS_EQUAL(this.get_status_type() , status_type);
       `FAIL_UNLESS_EQUAL(this.get_status_seq_id(), status_seq_id);
//   endfunction : assert_status_packet
      endtask: assert_status_packet

   // Interfaces passed as args to tasks and functions must be virtual:
   // ieee 1800-2017: 25.9 "Virtual Interfaces"
   task copy_to_pkt(virtual interface pkt_stream_t axis_bus);

      logic [63:0] tdata;
      logic        tlast;

      axis_bus.pull_beat(tdata,tlast);
      `FAIL_UNLESS_EQUAL(tlast,0);
      this.set_raw_header(tdata);
      axis_bus.pull_beat(tdata,tlast);
      `FAIL_UNLESS_EQUAL(tlast,0);
      this.set_timestamp(tdata);
      payload = new[bytes_to_beats(this.header.length-16)];
      // Assert on tlast is done one pass in arrears so that we can check for tlast==1
      // once foreach quits.
      foreach (payload [i]) begin
         `FAIL_UNLESS_EQUAL(tlast, 0);
         axis_bus.pull_beat(tdata,tlast);
         payload[i] = tdata;
      end
      `FAIL_UNLESS_EQUAL (tlast, 1);
   endtask : copy_to_pkt


    function bit is_same(DRaTPacket test_packet, bit use_assertion=1);
        //pkt_header_t test_header;
        //pkt_payload_t test_payload;
        //test_header = test_packet.get_header();
        //test_payload
        if (use_assertion) begin
            assert(header_compare(this.header,test_packet.get_header()));
            assert(payload_compare(this.payload,test_packet.get_payload()));
            return(1); // Should not get here if assert triggered
        end else begin
            return(header_compare(this.header,test_packet.get_header()) &&
                   payload_compare(this.payload,test_packet.get_payload()));
        end
    endfunction: is_same

endclass : DRaTPacket

endpackage



//-------------------------------------------------------------------------------
//-- Inherit basic AXIS interface into packet aware interface
//-------------------------------------------------------------------------------
interface pkt_stream_t (input clk);
   import drat_protocol::*;
   axis_t #(.WIDTH(64)) axis (.clk(clk));


   //
   // Push Header onto packet stream
   //
   task automatic push_header;
      input pkt_header_t header;
      axis.write_beat(extract_header(header),0);
      axis.write_beat(extract_timestamp(header),0);
   endtask : push_header

   //
   // Push data beat onto packet stream
   //
   task automatic push_payload;
      input logic [63:0] beat;
      input logic        last;
      axis.write_beat(beat,last);
   endtask : push_payload

   //
   // Push idle cycle
   //
   task automatic push_idle;
      axis.idle_master;
   endtask : push_idle

   //
   // Pop Beat off a stream
   //
   task automatic pull_beat;
      output logic [63:0] beat;
      output logic        last;
      axis.read_beat(beat,last);
   endtask : pull_beat

    //
    // Push full DRaT packet onto Packet bus.
    //
    task automatic push_pkt;
        ref DRaTPacket packet;
        axis.write_beat(packet.get_raw_header(),0);
        axis.write_beat(packet.get_timestamp(),0);
        packet.rewind_payload();
        // Subtract 2 beats for omitted header (and 1 for tlast cycle which comes after loop)
        for (integer i=0; i < (bytes_to_beats(packet.get_length()) - 3); i++) begin
            axis.write_beat(packet.get_beat(),0);
        end
        axis.write_beat(packet.get_beat(),1);
    endtask : push_pkt

    //
    // Pop full DRaT packet off a packet bus
    //
    task automatic pop_pkt;
        ref DRaTPacket packet;
        logic [63:0] beat;
        logic        last;

        axis.read_beat(beat,last);
        assert(last===1'b0);
        packet.set_raw_header(beat);
        axis.read_beat(beat,last);
        assert(last===1'b0);
        packet.set_timestamp(beat);
        packet.reset_payload(bytes_to_beats(packet.get_length()-16));
        packet.rewind_payload();
        // Subtract 2 beats for omitted header (and 1 for tlast cycle which comes after loop)
        for (integer i=0; i < (bytes_to_beats(packet.get_length()) - 3); i++) begin
            axis.read_beat(beat,last);
            packet.set_beat(beat);
            assert(last===1'b0)
                begin end else $error("TLAST in unexpected state %d on beat %d with packet lenth %d ",last,i,packet.get_length());

        end
        axis.read_beat(beat,last);
        packet.set_beat(beat);
        assert(last===1'b1);
    endtask // pop_pkt


endinterface // pkt_stream_t
`endif //  `ifndef _DRAT_PROTOCOL_SV_
   
