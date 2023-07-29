//-----------------------------------------------------------------------------
// File:    eth_router_2_port.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`include "global_defs.svh"
`include "ethernet.sv"


module drat2eth_framer
  (

   input logic        clk,
   input logic        rst,
   // CSR interface
   input logic [47:0] csr_mac_dst,
   input logic [47:0] csr_mac_src,
   input logic [31:0] csr_ipv4_dst,
   input logic [31:0] csr_ipv4_src,
   input logic [15:0] csr_udp_dst1,
   input logic [15:0] csr_udp_src1,
   input logic [15:0] csr_udp_dst2,
   input logic [15:0] csr_udp_src2,
   input logic [15:0] csr_udp_dst3,
   input logic [15:0] csr_udp_src3,
   input logic [15:0] csr_udp_dst4,
   input logic [15:0] csr_udp_src4,   
   input logic        csr_enable,
   output logic       csr_idle,
                      
                      
                      
   // DRaT protocol input bus (64b TDATA)
   axis_t.slave in_axis,
   // Ethernet/IPv4/UDP encapsulated output bus (68b TDATA)
   axis_t.master out_axis
   
   );

   // Constants
   localparam logic [15:0] C_ETHERTYPE = 16'h0800; 
   localparam logic [3:0]  C_VERSION = 4'd4;         // IPv4
   localparam logic [3:0]  C_IHL = 4'd5;             // Standard IPv4 header with no options
   localparam logic [7:0]  C_DSCP_ECN = 8'd0;        // DSCP and ECN unused
   localparam logic [15:0] C_IDENTIFICATION = 16'd0; // Unused
   localparam logic [2:0]  C_FLAGS = 3'b010;         // Don't fragment
   localparam logic [12:0] C_FRAGMENT_OFFSET = 13'd0;// Don't fragment
   localparam logic [7:0]  C_TIME_TO_LIVE = 8'd16;   // TTL
   localparam logic [7:0]  C_PROTOCOL = 8'd17;       // UDP
   localparam logic [15:0] C_UDP_CHECKSUM = 16'd0;   // UDP checksum dissabled.
   // Precalculate constant parts of IPv4 header checksum
   localparam logic [17:0] C_PRECALC_CHECKSUM = {C_ETHERTYPE, C_VERSION, C_IHL} + {C_FLAGS, C_FRAGMENT_OFFSET} + {C_TIME_TO_LIVE, C_PROTOCOL};
   
   
   drat_protocol::pkt_header_t drat_header;
   logic [15:0]            calc_length;
   logic [15:0]            udp_src, udp_dst;
   logic [18:0]            checksum_ipaddr;
   logic [18:0]            checksum_ipaddr_plus_len;
   logic [15:0]            ipv4_checksum;

   
   //-----------------------------------------------------------------------------
   // State machine
   //-----------------------------------------------------------------------------
   enum {
         S_IDLE,
         S_HEADER1,
         S_HEADER2,
         S_HEADER3,
         S_HEADER4,
         S_HEADER5,
         S_HEADER6,
         S_PAYLOAD,
         S_LAST
         } state;

   always_ff @(posedge clk) begin
        if (rst) begin
           state <= S_IDLE;
           drat_header <= '0;
           out_axis.tvalid <= 1'b0;
           out_axis.tlast <= 1'b0;
        end else begin
           case (state)
             // Use first beat of new packet to populate DRaT header structure
             S_IDLE: begin
                // Wait for the next DRaT packet to be valid
                if (csr_enable && in_axis.tvalid) begin
                   // Grab DRaT header
                   drat_header <= dirt_protocol::populate_header_no_timestamp(drat_in_axis.tdata);
                   state <= S_HEADER1;                 
                end
                csr_idle <= ~csr_enable;               
             end
             // 1st beat of header
             S_HEADER1: begin
                if (out_axis.tready == 1)
	          state <= S_HEADER2;
             end
             //            
             S_HEADER2: begin 
               if (out_axis.tready == 1)
	          state <= S_HEADER3;
             end
             //
             S_HEADER3: begin 
               if (out_axis.tready == 1)
	          state <= S_HEADER4;
             end
             //
             S_HEADER4: begin 
               if (out_axis.tready == 1)
	          state <= S_HEADER5;
             end
             //
             S_HEADER5: begin 
                if (out_axis.tready == 1)
	          state <= S_HEADER6;
            end
             //
             S_HEADER6: begin 
               if (out_axis.tready == 1)
	          state <= S_HEADER7;
             end
             //
             S_PAYLOAD: begin
                if ((in_axis.tvalid == 1) && (out_axis.tready == 1) && (in_tlast == 1))
	            state <= S_IDLE;
             end
             // Should never get to default
             default: begin
                state <= S_IDLE;
             end
           endcase // case (state)

        end // else: !if(rst)
   end // always_ff @ (posedge clk)

   // Recaclulate IPv4 and UDP packet lengths on the fly to re-use one adder and register.
   always_ff @(posedge clk) begin
      if ((state == S_HEADER1) || (state == S_HEADER4)) begin
         calc_length <= drat_header.length + (state == S_HEADER1) ? 16'd28 : 16'd8;
      end
   end

   // Use 2 LSB's of DRaT Flow_ID to choose from 4 UDP src/dst port tuples.
   always_comb begin
      case(drat_header.flow_id[1:0])
        0: begin
           udp_src = csr_udp_src1;
           udp_dst = csr_udp_dst1;
        end
          1:begin
           udp_src = csr_udp_src2;
           udp_dst = csr_udp_dst2;
        end
          2:begin
           udp_src = csr_udp_src3;
           udp_dst = csr_udp_dst3;
        end
            3:begin
           udp_src = csr_udp_src4;
           udp_dst = csr_udp_dst4;
            end
      endcase // case (drat_header.flow_id[1:0])
   end // always_comb
   

   // AXIS handshaking
   always_comb begin
      in_axis.tready = (state == S_PAYLOAD) ? out_axis.tready : 1'b0;
      out_axis.tlast = (state == S_PAYLOAD) ? in_axis.tlast : 1'b0;
      out_axis.tdata[67:64] = ((state == S_PAYLOAD) & in_axis.tlast) ? {1'b0,vita_len[0],2'b00} : 4'b0000; // IJB. Think about this more
   end

   ip_hdr_checksum ip_hdr_checksum
     (.clk(clk), .in({misc_ip,ip_len,ident,flag_frag,ttl_prot,16'd0,ip_src,ip_dst}),
      .out(iphdr_checksum));

   // Abreviated IPv4 header checksum calc because many fields are constant or pre-programmed.
   // Gate updates with state to capture correct IPv4 length value.
   always_ff @(posedge clk) begin
      if (state == S_HEADER1) 
        checksum_ipaddr <= csr_ip_src[15:0] +  csr_ip_dst[15:0] + csr_ip_src[31:16] +  csr_ip_dst[31:16] + C_PRECALC_CHECKSUM;
      if (state == S_HEADER2) 
        ipv4_checksum <= ~(checksum_ipaddr_plus_len[15:0] + checksum_ipaddr_plus_len[18:16]);
   end
    
   always_comb begin
      checksum_ipaddr_plus_len = checksum_ipaddr + calc_length;
   end

   // Mux TDATA source for egress to inject header fileds before payload beats.
   always_comb begin
      case(state)
        S_HEADER1 : out_axis.tdata[63:0] <= { 48'h0, csr_mac_dst[47:32]};
        S_HEADER2 : out_axis.tdata[63:0] <= { csr_mac_dst[31:0], csr_mac_src[47:16]};
        S_HEADER3 : out_axis.tdata[63:0] <= { csr_mac_src[15:0], C_ETHERTYPE, C_VERSION, C_IHL, calc_length };
        S_HEADER4 : out_axis.tdata[63:0] <= { C_IDENTIFICATION , C_FLAGS, C_FRAGMENT_OFFSET, C_TIME_TO_LIVE, C_PROTOCOL, ipv4_checksum;
        S_HEADER5 : out_axis.tdata[63:0] <= { csr_ip_src, csr_ip_dst};
        S_HEADER6 : out_axis.tdata[63:0] <= { udp_src, udp_dst, calc_length, C_UDP_CHECKSUM};
        default : out_axis.tdata[63:0] <= in_axis.tdata[63:0]; // Pass through payload.
      endcase // case (state)
   end

endmodule // drat2eth_framer
