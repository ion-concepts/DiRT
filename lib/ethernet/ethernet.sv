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

// Pull in AXI Streaming libarary.
`ifndef _AXIS_SV_
 `include "axis.sv"
`endif

// Relies on SVUnit
`include "svunit_defines.svh"

package ethernet_protocol;
   // Make the math trivial to calculate bytes from beats.

   // (xsim in 2022.2 does not support 'let')
   let beats_to_bytes(x) = (x)*8;
   let bytes_to_beats(x) = (((x)+7)>>3);

   //-------------------------------------------------------------------------------
   //-- Ethernet header definition
   //-------------------------------------------------------------------------------
   typedef enum logic [15:0]
                {
                 IPV4 = 16'h0800,
                 ARP =  16'h0806,
                 IPV6 = 16'h86DD,
                 FLOW_CONTROL = 16'h8808,
                 PTP =  16'h88F7
                 } ethertype_enum_t;

   typedef union packed
                 {
                    ethertype_enum_t ethertype_enum;
                    logic [15:0] ethertype_raw;
                 } ethertype_t;

   typedef struct packed
                  {
                     logic [47:0] mac_dst;
                     logic [47:0] mac_src;
                     ethertype_t ethertype;
                  } eth_header_t; // 112bits

   //-------------------------------------------------------------------------------
   //-- IPv4 header definition
   //-------------------------------------------------------------------------------
   typedef enum logic [7:0]
                {
                   ICMP = 8'h01,
                   IGMP = 8'h02,
                   TCP =  8'h06,
                   UDP =  8'h11
                 } ipv4_proto_enum_t;

   typedef union packed
                 {
                    ipv4_proto_enum_t ipv4_proto_enum;
                    logic [7:0] ipv4_proto_raw;
                 } ipv4_proto_t;

   typedef struct packed
                  {
                     logic [7:0] octet_a;
                     logic [7:0] octet_b;
                     logic [7:0] octet_c;
                     logic [7:0] octet_d;
                  } ipv4_octets_t;

   typedef union packed
                 {
                    logic [31:0] ip_addr;
                    ipv4_octets_t ip_octets;
                 } ipv4_addr_t;

   typedef struct packed
                  {
                     logic [3:0] version;
                     logic [3:0] ihl;
                     logic [5:0] dscp;
                     logic [1:0] ecn;
                     logic [15:0] length;
                     logic [15:0] identification;
                     logic [2:0] flags;
                     logic [12:0] fragment;
                     logic [7:0]  ttl;
                     ipv4_proto_t  protocol;
                     logic [15:0] checksum;
                     ipv4_addr_t src_addr;
                     ipv4_addr_t dst_addr;
                  } ipv4_header_t; // 160bits

   //-------------------------------------------------------------------------------
   //-- UDP header definition
   //-------------------------------------------------------------------------------

   typedef struct packed
                  {
                     logic [15:0] src_port;
                     logic [15:0] dst_port;
                     logic [15:0] length;
                     logic [15:0] checksum;
                  } udp_header_t; //64bits

   //-------------------------------------------------------------------------------
   //-- ICMP header definition
   //-------------------------------------------------------------------------------

   // Just PING support currently.
   typedef enum logic [7:0]
                {
                   ECHO_REPLY = 8'h00,
                   ECHO_REQUEST = 8'h08
                 }  icmp_type_enum_t;

   typedef union packed
                 {
                    logic [7:0] type_raw;
                    icmp_type_enum_t type_enum;
                 } icmp_type_t;

   typedef struct packed
                  {
                     icmp_type_t icmp_type;
                     logic [7:0] code;
                     logic [15:0] checksum;
                     logic [15:0] identifier; // Presumes ECHO
                     logic [15:0] seq_num; // Presumes ECHO
                  } icmp_header_t;

   //-------------------------------------------------------------------------------
   // Generic Payload is composed of variable number of octets after header
   //-------------------------------------------------------------------------------
   typedef logic[7:0] pkt_payload_t [];
   // NOTE: Can't build a struct containing a pkt_header_t and pkt_payload_t because
   // its illegal to have packed structs mixed with dynamic arrays.


   //-------------------------------------------------------------------------------
   //-- Given a packet header structure, expand into vectors of bits.
   //-------------------------------------------------------------------------------
   function logic [111:0] extract_eth_header (input eth_header_t header);
      return {
              header.mac_dst,
              header.mac_src,
              header.ethertype
              };
   endfunction : extract_eth_header

   function logic [159:0] extract_ipv4_header (input ipv4_header_t header);
      return {
              header.version,
              header.ihl,
              header.dscp,
              header.ecn,
              header.length,
              header.identification,
              header.flags,
              header.fragment,
              header.ttl,
              header.protocol,
              header.checksum,
              header.src_addr,
              header.dst_addr
              };
   endfunction : extract_ipv4_header

   function logic [63:0] extract_udp_header  (input udp_header_t header);
      return {
              header.src_port,
              header.src_port,
              header.length,
              header.checksum
              };
   endfunction : extract_udp_header

   //
   // Generic Ethernet Packet type.
   // Provides general packet manipulation and low level test functions.
   // Designed for inhertance to support specific packet formats.
   //
class EthernetPacket;
   protected eth_header_t eth_header;
   protected pkt_payload_t payload;
   local int          next;


   // Provide explicit constructor
   // len: Size of ultimate payload in octets (NOT including any other encapsulated protocol headers)
   function new(ethertype_enum_t ethertype = IPV4, shortint len=1);
      eth_header.mac_dst = 0;
      eth_header.mac_src = 0;
      eth_header.ethertype.ethertype_enum = ethertype ;
      payload = new[len];
      next = 0;

   endfunction // init_eth_header

   // Set MAC DST address
   function void set_mac_dst(logic[47:0] mac_dst);
      this.eth_header.mac_dst = mac_dst;
   endfunction: set_mac_dst

   // Returns MAC DST address
   function shortint get_mac_dst();
      return(this.eth_header.mac_dst);
   endfunction : get_mac_dst

  // Set MAC SRC address
   function void set_mac_src(logic[47:0] mac_src);
      this.eth_header.mac_src = mac_src;
   endfunction: set_mac_src

   // Returns MAC SRC address
   function shortint get_mac_src();
      return(this.eth_header.mac_src);
   endfunction : get_mac_src

   // Set MAC SRC address
   function void set_ethertype(ethertype_enum_t ethertype);
      this.eth_header.ethertype = ethertype;
   endfunction: set_ethertype

   // Returns MAC SRC address
   function shortint get_ethertype();
      return(this.eth_header.ethertype);
   endfunction : get_ethertype

   //-----------------------------------------------------
   //-- Generic payload manipulation for all packet types
   //-- assumes octet quanta
   //-----------------------------------------------------

   // Return packet payload to minimal initialized state.
   function void reset_payload(shortint len=1);
      this.payload=new[len];
   endfunction : reset_payload

   // Return entire payload as array
   function pkt_payload_t get_payload();
      return(this.payload);
   endfunction : get_payload

   // Return size of alocated payload array
   function shortint get_payload_length();
      return(this.payload.size());
   endfunction : get_payload_length

   // Packets payload is already allocated.
   // Add octet to packet using
   // private index pointer
   function void set_payload_octet(bit [7:0] octet);
      this.payload[next] = octet;
      next = next + 1;
   endfunction : set_payload_octet

   // Populate 8 consectutive payload octets
   function void set_payload_8octets(bit [63:0] beat);
      set_payload_octet(beat[63:56]);
      set_payload_octet(beat[55:48]);
      set_payload_octet(beat[47:40]);
      set_payload_octet(beat[39:32]);
      set_payload_octet(beat[31:24]);
      set_payload_octet(beat[23:16]);
      set_payload_octet(beat[15:8]);
      set_payload_octet(beat[7:0]);
   endfunction : set_payload_8octets

   // Return next payload beat
   function bit [7:0] get_payload_octet();
      next = next + 1;
      return(this.payload[next-1]);
   endfunction : get_payload_octet

   // Add octet to end of packet without being protocol aware.
   // Allocate additional storage.
   // (i.e we don't look at or change the header)
   function void add_payload_octet(bit [7:0] octet);
      payload = new[this.payload.size()+1] (payload);
      payload[this.payload.size()-1] = octet;
   endfunction : add_payload_octet

   // Reset payload pointer back to start.
   function void rewind_payload();
      next = 0;
   endfunction : rewind_payload


   // TODO: Solve CRC creation. Might need to be part of super class since this class can not see full packet.

endclass : EthernetPacket

   //
   // Generic IPv4 Packet type.
   // Provides general packet manipulation and low level test functions.
   // Inherits EthernetPacket as a base class.
   // Designed for inhertance to support specific packet formats.
   //

class IPv4Packet extends EthernetPacket;
  protected ipv4_header_t ipv4_header;

   // Provide explicit constructor
   // len: Size of ultimate payload in octets (NOT including any other encapsulated protocol headers)
   function new(ipv4_proto_enum_t ipv4_proto_enum = UDP, shortint len=1);
      super.new(IPV4,len);
      ipv4_header.version = 4;
      ipv4_header.ihl = 5;
      ipv4_header.dscp = 0;
      ipv4_header.ecn = 0;
      case(ipv4_proto_enum)
        UDP: ipv4_header.length = 20+8+len;
        ICMP: ipv4_header.length = 20+8+len;
        IGMP: assert(0); // Need to finish support
        TCP: assert(0); // Need to finish support
      endcase
      ipv4_header.identification = 0;
      ipv4_header.flags = 3'b010;
      ipv4_header.fragment = 0;
      ipv4_header.ttl = 8'h10;
      ipv4_header.protocol.ipv4_proto_enum = ipv4_proto_enum;
      ipv4_header.checksum = 0;
      ipv4_header.src_addr.ip_addr = {8'd0,8'd0,8'd0,8'd0};
      ipv4_header.dst_addr.ip_addr = {8'd0,8'd0,8'd0,8'd0};
   endfunction // init_ipv4_header

   // Returns size of a IPv4 header in octets
   function ipv4_header_size();
      return('d20);
   endfunction: ipv4_header_size

   // Set length of IPv4 packet (in bytes)
   function void set_ipv4_length(shortint length);
      this.ipv4_header.length = length;
   endfunction: set_ipv4_length

   // Returns confgured length of packet (in bytes)
   function shortint get_ipv4_length();
      return(this.ipv4_header.length);
   endfunction : get_ipv4_length

   // Set ttl of IPv4 packet
   function void set_ipv4_ttl(shortint ttl);
      this.ipv4_header.ttl = ttl;
   endfunction: set_ipv4_ttl

   // Returns confgured ttl of packet
   function shortint get_ipv4_ttl();
      return(this.ipv4_header.ttl);
   endfunction : get_ipv4_ttl

   // Set src_addr of IPv4 packet
   function void set_ipv4_src_addr(logic[31:0] src_addr);
      this.ipv4_header.src_addr.ip_addr = src_addr;
   endfunction: set_ipv4_src_addr

   // Returns confgured src_addr of packet
   function shortint get_ipv4_src_addr();
      return(this.ipv4_header.src_addr.ip_addr);
   endfunction : get_ipv4_src_addr

   // Set dst_addr of IPv4 packet
   function void set_ipv4_dst_addr(logic[31:0] dst_addr);
      this.ipv4_header.dst_addr.ip_addr = dst_addr;
   endfunction: set_ipv4_dst_addr

   // Returns confgured dst_addr of packet
   function shortint get_ipv4_dst_addr();
      return(this.ipv4_header.dst_addr.ip_addr);
   endfunction : get_ipv4_dst_addr

   // Pass down octet postpend to super class, increment local packet header length
   function void add_payload_octet(bit [7:0] octet);
      super.add_payload_octet(octet);
      ipv4_header.length = ipv4_header.length + 1;
   endfunction : add_payload_octet

   // TODO: Calculate IPv4 header checksum
   function void calculate_ipv4_checksum();
      logic [19:0]    sum;
      logic [159:0]   header;

      header = this.ipv4_header;

      sum =
           header[15:0] +
           header[31:16] +
           header[47:32] +
           header[63:48] +
           //header[79:64] + Checksum is 0 for calculation
           header[95:80] +
           header[111:96] +
           header[127:112] +
           header[143:128] +
           header[159:144];
      // First iteration of carry folding
      sum = sum[15:0] + sum[19:16];
      // Second iteration of carry folding (Should be max 1 carry bit here)
      sum = sum[15:0] + sum[19:16];

      this.ipv4_header.checksum = ~(sum[15:0]);

   endfunction : calculate_ipv4_checksum




      /*
       module ip_hdr_checksum
  (input clk, input [159:0] in, output reg [15:0] out);

   wire [18:0] padded [0:9];
   reg [18:0]  sum_a, sum_b;

   genvar     i;
   generate
      for(i=0 ; i<10 ; i=i+1)
	assign padded[i] = {3'b000,in[i*16+15:i*16]};
   endgenerate

   always @(posedge clk)  sum_a = padded[0] + padded[1] + padded[2] + padded[3] + padded[4];
   always @(posedge clk)  sum_b = padded[5] + padded[6] + padded[7] + padded[8] + padded[9];

   wire [18:0] sum = sum_a + sum_b;

   always @(posedge clk)
     out <= ~(sum[15:0] + {13'd0,sum[18:16]});
*/

endclass : IPv4Packet


class UDPPacket extends IPv4Packet;
   protected udp_header_t udp_header;

   // Provide explicit constructor
   // len: Size of ultimate payload in octets (NOT including any other encapsulated protocol headers)
   function new(shortint len=1);
      super.new(UDP,len);
      udp_header.src_port = 0;
      udp_header.src_port = 0;
      udp_header.length = 8 + len;
      udp_header.checksum = 0; // 0 checksum is legal if unused
   endfunction // init_udp_header

   // Returns size of a UDP header in octets
   function udp_header_size();
      return('d8);
   endfunction: udp_header_size

   // Set src_port of UDP packet
   function void set_udp_src_port(logic[15:0] src_port);
      this.udp_header.src_port = src_port;
   endfunction: set_udp_src_port

   // Returns confgured UDP src_port of packet
   function shortint get_udp_src_port();
      return(this.udp_header.src_port);
   endfunction : get_udp_src_port

   // Set dst_port of UDP packet
   function void set_udp_dst_port(logic[15:0] dst_port);
      this.udp_header.dst_port = dst_port;
   endfunction: set_udp_dst_port

   // Returns confgured UDP dst_port of packet
   function shortint get_udp_dst_port();
      return(this.udp_header.dst_port);
   endfunction : get_udp_dst_port

   // Set length of Udp packet (in bytes)
   function void set_udp_length(shortint length);
      this.udp_header.length = length;
   endfunction: set_udp_length

   // Returns confgured length of packet (in bytes)
   function shortint get_udp_length();
      return(this.udp_header.length);
   endfunction : get_udp_length

   // Pass down octet postpend to super class, increment local packet header length
   function void add_payload_octet(bit [7:0] octet);
      super.add_payload_octet(octet);
      udp_header.length = udp_header.length + 1;
   endfunction : add_payload_octet

   // Push entire UDP onto eth_stream_t bus.
   // This includes the 4 TUSER bits to support octet sized bursts and an error flag.
   task send_udp_to_eth_stream(virtual interface eth_stream_t axis_bus, bit use_assertion=1);
      integer payload_len;
      logic [67:0] beat;
      axis_bus.push_beat({4'h0,48'h0,this.eth_header[111:96]},0);
      axis_bus.push_beat({4'h0,this.eth_header[95:32]},0);
      axis_bus.push_beat({4'h0,this.eth_header[31:0],ipv4_header[159:128]},0);
      axis_bus.push_beat({4'h0,this.ipv4_header[127:64]},0);
      axis_bus.push_beat({4'h0,this.ipv4_header[63:0]},0);
      // If we support UDP with 0 payload length then this next burst needs TLAST support.
      axis_bus.push_beat({4'h0,this.udp_header[63:0]},0);
      payload_len = this.udp_header.length - 8;
      if (use_assertion) begin
         assert(payload_len==this.get_payload_length());
      end else begin
         if (payload_len!=this.get_payload_length())
         $display("ERROR: UDP payload length missmatch. UDP header: %d,  Allocated %d", payload_len, this.get_payload_length());
      end
      this.rewind_payload();
      // Iterate over whole beats.
      while (payload_len > 8) begin
         beat = 68'h0;
         for (integer i=0; i < 8; i++) begin
            beat = (beat << 8) | this.get_payload_octet();
         end
         axis_bus.push_beat(beat,0);
         payload_len = payload_len - 8;
      end
      beat = 68'h0;
      for (integer i=0; i < payload_len; i++) begin
         beat = (beat << 8) | this.get_payload_octet();
      end
      // (Wrap 8 to 0)
      beat[66:64] = payload_len[2:0];
      beat[67] = 0; // Error not set.
      axis_bus.push_beat(beat,1);
    endtask // send_udp_to_eth_stream

   // Push entire UDP packet, without Ethernet headers, onto 64bit axis_t bus.
   task send_udp_to_ipv4_stream(virtual interface axis_t axis_bus, bit use_assertion=1);
      integer payload_len;
      logic [63:0] beat;

      axis_bus.write_beat({this.eth_header[31:0],ipv4_header[159:128]},0);
      axis_bus.write_beat(this.ipv4_header[127:64],0);
      axis_bus.write_beat(this.ipv4_header[63:0],0);
      // If we support UDP with 0 payload length then this next burst needs TLAST support.
      axis_bus.write_beat(this.udp_header[63:0],0);
      payload_len = this.udp_header.length - 8;
      if (use_assertion) begin
         assert(payload_len==this.get_payload_length());
      end else begin
         if (payload_len!=this.get_payload_length())
         $display("ERROR: UDP payload length missmatch. UDP header: %d,  Allocated %d", payload_len, this.get_payload_length());
      end
      this.rewind_payload();
      // Iterate over whole beats.
      while (payload_len > 8) begin
         beat = 64'h0;
         for (integer i=0; i < 8; i++) begin
            beat = (beat << 8) | this.get_payload_octet();
         end
         axis_bus.write_beat(beat,0);
         payload_len = payload_len - 8;
      end
      beat = 64'h0;
      for (integer i=0; i < payload_len; i++) begin
         beat = (beat << 8) | this.get_payload_octet();
      end
      axis_bus.write_beat(beat,1);
    endtask // send_udp_to_ipv4_stream

   // Push entire UDP+IPv4 packet, without Ethernet headers, onto 8bit axis_t bus.
   // UDP payload must be 1 or greater in size.
   task send_udp_to_octet_stream(virtual interface axis_t #(.WIDTH(8)) axis_bus, bit use_assertion=1);
      integer payload_len;
      logic [7:0] beat;
      logic [159:0] tmp;
      logic [7:0] tmp2;

      // "Range must be bounded by constant expressions"
      // Direct bit range select not aloowed so resort to right shift to select octets.
      tmp = this.ipv4_header[159:0];
      // Serialize the IPv4 header to octets
      for (integer i=152; i >= 0 ; i=i-8) begin
         tmp2 = (tmp >> i) & 8'hff;
         axis_bus.write_beat(tmp2,0);
      end
      tmp = this.udp_header[63:0];
      // Serialize the UDP header to octets
      for (integer i=56; i >= 0 ; i=i-8) begin
         tmp2 = (tmp >> i) & 8'hff;
         axis_bus.write_beat(tmp2,0);
      end
      // Serialize payload to octets
      payload_len = this.udp_header.length - 8;
      if (use_assertion) begin
         assert(payload_len==this.get_payload_length());
      end else begin
         if (payload_len!=this.get_payload_length())
         $display("ERROR: UDP payload length missmatch. UDP header: %d,  Allocated %d", payload_len, this.get_payload_length());
      end
      this.rewind_payload();
      // Iterate over payload
      while (payload_len > 1) begin
         axis_bus.write_beat(this.get_payload_octet(),0);
         payload_len--;
      end
      axis_bus.write_beat(this.get_payload_octet(),1);
    endtask // send_udp_to_octet_stream



endclass : UDPPacket


class ICMPPacket extends IPv4Packet;
   protected icmp_header_t icmp_header;


   // Provide explicit constructor
   function new(shortint len=1);
      super.new(ICMP,len);
      icmp_header.icmp_type.type_enum = ECHO_REQUEST;
      icmp_header.code = 0;
      icmp_header.identifier = 0;
      icmp_header.seq_num = 0;
   endfunction // new

   // Set ICMP type (enum)
   function void set_icmp_type(icmp_type_enum_t icmp_type);
      this.icmp_header.icmp_type.type_enum = icmp_type;
   endfunction: set_icmp_type

   // Returns ICMP type (enum)
   function shortint get_icmp_type();
      return(this.icmp_header.icmp_type.type_enum);
   endfunction : get_icmp_type

   // Set ICMP code
   function void set_icmp_code(logic[7:0] code);
      this.icmp_header.code = code;
   endfunction: set_icmp_code

   // Returns ICMP code
   function shortint get_icmp_code();
      return(this.icmp_header.code);
   endfunction : get_icmp_code

   // Set ICMP identifier
   function void set_icmp_identifier(logic[15:0] identifier);
      this.icmp_header.identifier = identifier;
   endfunction: set_icmp_identifier

   // Returns ICMP identifier
   function shortint get_icmp_identifier();
      return(this.icmp_header.identifier);
   endfunction : get_icmp_identifier

   // Set ICMP seq_num
   function void set_icmp_seq_num(logic[15:0] seq_num);
      this.icmp_header.seq_num = seq_num;
   endfunction: set_icmp_seq_num

   // Returns ICMP seq_num
   function shortint get_icmp_seq_num();
      return(this.icmp_header.seq_num);
   endfunction : get_icmp_seq_num

   // Set ICMP checksum
   function void set_icmp_checksum(logic[15:0] checksum);
      this.icmp_header.checksum = checksum;
   endfunction: set_icmp_checksum

   // Returns ICMP checksum
   function shortint get_icmp_checksum();
      return(this.icmp_header.checksum);
   endfunction : get_icmp_checksum

   // Pass down octet postpend to super class
   function void add_payload_octet(bit [7:0] octet);
      super.add_payload_octet(octet);
   endfunction : add_payload_octet

endclass : ICMPPacket
endpackage // ethernet_protocol



//-------------------------------------------------------------------------------
//-- Inherit basic AXIS interface into ethernet aware interface
//-- Interface includes:
//--   64b data path for ethernet encapsulated packets.
//--   4b flags (per beat that are only valid for the last beat in a packet
//--   flag[2:0] encode the number of valid octets in the last beat, where 3'b0 = 8 octets
//--   flag[3] indicates an error in the packet and all proceding beats should be discarded.
//--   flag[3] may be set in lieu of an asserted TLAST or both may be asserted.
//-- flags are nominally TUSER bits but are concatonated as TDATA[67:64] for ease of use with axis_t
//-------------------------------------------------------------------------------
interface eth_stream_t (input clk);
   import ethernet_protocol::*;
   axis_t #(.WIDTH(68)) axis (.clk(clk));

 /*
   //
   // Push ethernet packet Headers onto packet stream
   //
   task automatic push_eth_header;
      input eth_header_t header;
      axis.write_beat(extract_eth_beat1(header),0);


   //
   // Push UDP packet Headers onto packet stream
   //
   task automatic push_udp_header;
      input udp_header_t header;
      integer beats_in_udp_header = 6;
      // First beat is special case to align UDP
      // at 64b beat.
      axis.write_beat({48'h000000000000,header
      for (integer i=0; i < ; i++) begin

      axis.write_beat(extract_beat1(header),0);
      axis.write_beat(extract_beat2(header),0);
      axis.write_beat(extract_beat3(header),0);
      axis.write_beat(extract_beat4(header),0);
      axis.write_beat(extract_beat5(header),0);
      axis.write_beat(extract_beat6(header),0);
   endtask : push_header
*/
   //
   // Push data beat onto packet stream
   //
   task automatic push_beat;
      input logic [63:0] beat;
      input logic        last;
      axis.write_beat(beat,last);
   endtask : push_beat

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

endinterface // eth_stream_t


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

   // NOTE: tx_clk follows MII style direction to match Xilinx PCS/PMA
   modport xilinx_mac (input txclk, output txd, output txen, output txer,
                input rxclk, input rxd, input rxdv,
                input rxer, input col, input cs);

   modport xilinx_phy (output txclk, input txd, input txen, input txer,
                output rxclk, output rxd, output rxdv,
                output rxer, output col, output cs);

   // NOTE: Real GMII source synchronous clocking
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
   modport phy (input mdc, input mdo, output mdi, output mdt);
   modport monitor (input mdc, input mdo, input mdi, input mdt);



endinterface : mdio_t




`endif //  `ifndef _ETHERNET_SV_
