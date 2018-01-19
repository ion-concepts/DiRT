//-------------------------------------------------------------------------------
//-- File:    protocol.sv
//--
//-- Author:  Ian Buckley
//--
//-- Description:
//-- Library of tasks to assist simulations of packet traffic over axis buses.
//--
//--
//--
//-------------------------------------------------------------------------------

`ifndef _PROTOCOL_SV_
 `define _PROTOCOL_SV_

// Pull in AXI Streaming libarary.
 `include "axis.sv"

// Make the math trivial to calculate bytes from beats.
 `define BEATS_TO_BYTES(x) (x)*8
 `define BYTES_TO_BEATS(x) (((x)+7)>>3)


// Enumerate the various defined packet types
typedef enum logic [7:0]
  {
   INT16_COMPLEX=8'h00,    //Integer complex numbers in a 16bit format. Used for example for IQ sample data.
   INT16_REAL=8'h01,       //Integer real numbers in a 16bit format. Used for example, for real valued sample data.
   //  INT12_COMPLEX,      //Integer complex numbers in a 12bit (packed) format. Used for example for IQ sample data.
   //  INT12_REAL,         //Integer real numbers in a 12bit (packed) format. Used for example for IQ sample data
   FLOAT32_COMPLEX=8'h02,  //Float complex numbers in an IEEE 32bit format. Used for example for IQ sample data
   FLOAT32_REAL=8'h03,     //Float real numbers in an IEEE 32bit format. Used for example for IQ sample data
   WRITE_MM32=8'h80,       //Create single 32bit memory mapped write transaction (single beat - no burst).
   READ_MM32=8'h81,	   //Create single 32bit memory mapped read transaction (single beat - no burst).
   WRITE_MM16=8'h82,	   //Create single 16bit memory mapped write transaction (single beat - no burst).
   READ_MM16=8'h83,	   //Create single 16bit memory mapped read transaction (single beat - no burst).
   WRITE_MM8=8'h84,	   //Create single 8bit memory mapped write transaction (single beat - no burst).
   READ_MM8=8'h85,	   //Create single 8bit memory mapped read transaction (single beat - no burst).
   STATUS=8'hC0,	   //Provides "execution" status for other packets back towards host
   FLOW_CREDIT=8'hC1,	   //Returns flow control credit back to source from sink.
   STRUCTURED=8'hFF
   } pkt_type_t;

// addresses of flow src/sinks
typedef enum logic [15:0]
             {
              INPUT,
	      OUTPUT 
              } node_addr_t;



// Define a source / dest pairing of addresses to define a flow.
typedef struct packed
               {
                  node_addr_t flow_src;
                  node_addr_t flow_dst;
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
                  logic [63:0] timestamp;
                  flow_id_t flow_id;
                  logic [15:0] length;
                  logic [7:0]  seq_id;
                  pkt_type_t packet_type;
               } pkt_header_t;

// Payload is composed of variable number of beats after header
typedef logic [63:0] pkt_payload_t [];

// NOTE: Can't build a struct containing a pkt_header_t and pkt_payload_t because
// its illegal to have packed structs mixed with dynamic arrays.


//-------------------------------------------------------------------------------
//-- Given a packet header structure, expand into vectors of bits.
//-------------------------------------------------------------------------------
function logic [63:0] extract_header (input pkt_header_t header);
   return {header.packet_type, header.seq_id, header.length, header.flow_id};
endfunction // extract_header

function logic [63:0] extract_timestamp (input pkt_header_t header);
   return {header.timestamp};
endfunction // extract_header

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
endfunction // populate_header


//-------------------------------------------------------------------------------
//-- Compare two header structures, return 1 if equal, 0 otherwise.
//-------------------------------------------------------------------------------
function logic header_compare(input pkt_header_t a, input pkt_header_t b);
  return ((a.packet_type === b.packet_type) &&
          (a.seq_id === b.seq_id) &&
          (a.length === b.length) &&
          (a.flow_id === b.flow_id) &&
          (a.timestamp == b.timestamp));
endfunction // header_compare

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
// Generic Packet type.
// Provides general packet manipulation and low level test functions.
// Designed for inhertance to support specific packet formats.
//
class Packet;
   protected pkt_header_t header;
   protected pkt_payload_t payload;
   local int next;


   // Provide explicit initialization
   function void init;
      header.packet_type = INT16_COMPLEX;
      header.seq_id = 0;
      header.length = 8; // Illegal as-is, needs non zero payload.
      header.flow_id.flow_id = 0;
      header.timestamp = 0;
   endfunction
/* -----\/----- EXCLUDED -----\/-----
   // Return packet to minimal initialized state.
   function void reset();
      this.new;
   endfunction : reset
 -----/\----- EXCLUDED -----/\----- */

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
   endfunction: set_flow_id

   // Get the flow ID
   function flow_id_t get_flow_id();
      return(this.header.flow_id);
   endfunction: get_flow_id

   // Set Source of this packet
   function void set_flow_src(node_addr_t node_addr);
      this.header.flow_id.flow_addr.flow_src = node_addr;
   endfunction: set_flow_src

   // Set Destination of this packet
   function void set_flow_dst(node_addr_t node_addr);
      this.header.flow_id.flow_addr.flow_dst = node_addr;
   endfunction: set_flow_dst

   // Set Packet Type
   function void set_packet_type(pkt_type_t packet_type);
      this.header.packet_type = packet_type;
   endfunction: set_packet_type

   // Get Packet Type
   function pkt_type_t get_packet_type();
      return(this.header.packet_type);
   endfunction : get_packet_type

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

   // Return entire header as structure
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

   // Return next payload beat
   function bit [63:0] get_beat();
      next = next + 1;
      return(this.payload[next-1]);
   endfunction : get_beat

   // Reset payload pointer back to start.
   function void rewind_payload();
      next = 0;
   endfunction : rewind_payload

   // Add a new beat to end of current payload.
   // Adjust header to match
   // Assumes payload always has full beats. (length%8=0)
   function void add_beat(bit [63:0] beat);
      this.header.length = this.header.length + 8;
      payload = new[`BYTES_TO_BEATS(this.header.length-16)] (payload);
      payload[(this.header.length-24)>>3] = beat;
   endfunction : add_beat// add_beat

   // Generate a random payload of length determined by header
   // (Note size in header is in bytes and includes the header.
   // Also account for last line thats partially used by adding 7 bytes before /8)
   function void random();
      payload = new[`BYTES_TO_BEATS(this.header.length-16)];
      foreach (payload [i])
        payload[i] = {$random,$random};
   endfunction : random
endclass : Packet



//-------------------------------------------------------------------------------
//-- Inherit basic AXIS interface into packet aware interface
//-------------------------------------------------------------------------------
interface pkt_stream_t (input clk);
   axis_t #(.WIDTH(64)) axis (.clk(clk));

   //
   // Push Header onto packet stream
   //
   task automatic push_header;
      input pkt_header_t header;
      axis.write_beat(extract_header(header),0);
      axis.write_beat(extract_timestamp(header),0);
   endtask // push_header

   //
   // Push data beat onto packet stream
   //
   task automatic push_payload;
      input logic [63:0] beat;
      input logic        last;
      axis.write_beat(beat,last);
   endtask // push_payload

   //
   // Push idle cycle
   //
   task automatic push_idle;
      axis.idle_master;
   endtask // push_idle

   //
   // Pop Beat off a stream
   //
   task pull_beat;
      output logic [63:0] beat;
      output logic        last;
      axis.read_beat(beat,last);
   endtask // pull_beat




endinterface // pkt_stream_t

`endif
