//-----------------------------------------------------------------------------
// File:    eth_classifier_2_egress.sv
//
// Author:  Ian Buckley, Ion Concepts LLC.
//
// Description:
// Deep packet inspection of ingressing ethernet frames on a 64bit AXIS bus
// Output switched between 2 egress ports.
// Can optionally strip L1-4 protocols for Egress port out1
// Port out1 will alway include tuser bits embedded in tdata even if DRaT format.
// These can be discarded for DRaT packets.
//
// License: CERN-OHL-P (See LICENSE.md)
//
//-----------------------------------------------------------------------------
`include "global_defs.svh"
`include "ethernet.sv"


module eth_classifier_2_egress
  (

   input logic        clk,
   input logic        rst,
   //
   // Ingress ethernet bus to classify
   //
   axis_t.slave in_axis,
   //
   // Two possible egress busses.
   //
   axis_t.master out0_axis, // Assumed to be default, with full TCP/IP stack downstream, 4 tuser bits included
   axis_t.master out1_axis, // Assumed to be DRaT protocol datapath, no tuser bits included.
   //
   // CSR
   //
   input logic [47:0] csr_mac,
   input logic [31:0] csr_ip,
   input logic [15:0] csr_udp0,
   input logic [15:0] csr_udp1,
   input logic        csr_expose_drat,
   input logic        csr_enable //TODO
   );

   axis_t #(.WIDTH(68)) out0_pre_axis(.clk(clk)), out1_pre_axis(.clk(clk));

   logic       is_eth_dst_addr;
   logic       is_eth_broadcast;
   logic       is_eth_multicast;
   logic       is_eth_type_ipv4;
   logic       is_ipv4_dst_addr;
   logic       is_ipv4_proto_udp;
   logic       is_ipv4_proto_icmp;
   logic [1:0] is_udp_dst_ports;
   logic       is_icmp_no_fwd;
   logic       is_chdr;

   // Small async RAM bult from CLB's stores packet header during parsing.
   localparam  HEADER_RAM_SIZE = 9;
   (*ram_style="distributed"*) logic [68:0]   header_ram [HEADER_RAM_SIZE-1:0];

   logic [3:0] header_ram_addr;
   logic       header_done;
   logic       fwd_input;
   logic [63:0] in_tdata_reg;
   axis_t #(.WIDTH(68)) out_axis (.clk(clk));


   //---------------------------------------------------------
   // State machine declarations
   //---------------------------------------------------------

   enum         {
                 WAIT_PACKET,
                 READ_HEADER,
                 CLASSIFY_PACKET,
                 FORWARD_0,
                 FORWARD_0_AND_1,
                 FORWARD_1,
                 DROP_PACKET
                 } state;

   //---------------------------------------------------------
   // Packet Forwarding State machine.
   //---------------------------------------------------------
   always_comb begin
      header_done = (header_ram_addr == HEADER_RAM_SIZE-1);
   end

   always_ff @(posedge clk) begin
      if (rst) begin
         state <= WAIT_PACKET;
         header_ram_addr <= 0;
         fwd_input <= 0;
      end else begin
         case (state)
           // Wait in this state for a packet to start.
           // Write first beat of a new packet to Header RAM and transition to READ_HEADER.
           WAIT_PACKET: begin
              if (in_axis.tvalid && in_axis.tready) begin
                 header_ram[header_ram_addr] <= {in_axis.tlast,in_axis.tdata};
                 header_ram_addr <= header_ram_addr + 1;
                 state <= READ_HEADER;
              end
              fwd_input <= 0;
           end
           //
           // Continue to read complete packet header into Header RAM.
           //
           READ_HEADER: begin
              if (in_axis.tvalid && in_axis.tready) begin
                 header_ram[header_ram_addr] <= {in_axis.tlast,in_axis.tdata};
                 // Have we reached end of fields we parse in header or got a runt packet?
                 if (header_done || in_axis.tlast) begin
                    // Transition to packet classifier state.
                    state <= CLASSIFY_PACKET;
                 end // if (header_done || in_axis.tlast)
                 else begin
                    header_ram_addr <= header_ram_addr + 1;
                    state <= READ_HEADER;
                 end // else: !if(header_done || in_axis.tlast)
              end // if (in_axis.tvalid && in_axis.tready)
           end // case: READ_HEADER

           //
           // Classify Packet
           //
           CLASSIFY_PACKET: begin
              // Make decision about where this packet is forwarded to.

              if (is_eth_type_ipv4 && is_ipv4_proto_icmp) begin
                 // IPV4 and ICMP. Only send to Egress0
                 header_ram_addr <= 0;
                 state <= FORWARD_0;
              end else if (is_eth_broadcast || is_eth_multicast) begin
                 // MAC has broadcast addr or multicast bit set. Only send to Egress0
                 header_ram_addr <= 0;
                 state <= FORWARD_0;
              end else if (/*!is_eth_dst_addr*/0) begin
                 // MAC dst is not our address. Discard packet.
                 header_ram_addr <= HEADER_RAM_SIZE - 1;
                 state <= DROP_PACKET;
              end else if (is_ipv4_proto_udp && (is_udp_dst_ports != 0)) begin
                 // Has our MAC dst addr and has UDP port match.
                 // Jump to DRaT header if enabled to strip lower protocols.
                 header_ram_addr <= csr_expose_drat ? 6 : 0;
                 state <= FORWARD_1;
              end else begin
                 // Has our MAC dst addr but no UDP port match.
                 header_ram_addr <= 0;
                 state <= FORWARD_0;
              end
           end // case: CLASSIFY_PACKET

           //
           // Forward this packet to Egress0 only
           //
           FORWARD_0: begin
              if (out_axis.tvalid && out_axis.tready) begin
                 if (out_axis.tlast) begin
                    state <= WAIT_PACKET;
                 end
                 if (header_done) fwd_input <= 1;
                 header_ram_addr <= out_axis.tlast? 4'b0 : header_ram_addr + 1;
              end
           end
           //
           // Forward this packet to Egress1 only
           //
           FORWARD_1: begin
              if (out_axis.tvalid && out_axis.tready) begin
                 if (out_axis.tlast) begin
                    state <= WAIT_PACKET;
                 end
                 if (header_done) fwd_input <= 1;
                 header_ram_addr <= out_axis.tlast? 4'b0 : header_ram_addr + 1;
              end
           end
           //
           // Discard packet
           //
           DROP_PACKET: begin
              if (out_axis.tvalid && out_axis.tready) begin
                 if (out_axis.tlast) begin
                    state <= WAIT_PACKET;
                 end
                 if (header_done) fwd_input <= 1;
                 header_ram_addr <= out_axis.tlast? 4'b0 : header_ram_addr + 1;
              end
           end
           //
           // Default (Should never get t0 this state)
           // behave like WAIT_PACKET.
           // TODO: Assert in this state.
           //
           default: begin
              if (in_axis.tvalid && in_axis.tready) begin
                 header_ram[header_ram_addr] <= {in_axis.tlast,in_axis.tdata};
                 header_ram_addr <= header_ram_addr + 1;
                 state <= READ_HEADER;
              end
              fwd_input <= 0;
           end
         endcase // case (state)
      end // else: !if(rst)
   end // always_ff @ (posedge clk)

   //---------------------------------------------------------
   // Classifier State machine.
   // Deep packet inspection to L4 during header ingress.
   //---------------------------------------------------------
   // As the packet header is pushed into the RAM, set classification
   // bits so that by the time the input state machine reaches the
   // CLASSIFY_PACKET state, the packet has been fully identified.

   always_ff @(posedge clk) begin
      if (rst) begin
         is_eth_dst_addr <= 1'b0;
         is_eth_broadcast <= 1'b0;
         is_eth_multicast <= 1'b0;
         is_eth_type_ipv4 <= 1'b0;
         is_ipv4_dst_addr <= 1'b0;
         is_ipv4_proto_udp <=  1'b0;
         is_ipv4_proto_icmp <=  1'b0;
         is_udp_dst_ports <= 0;
      end else if (in_axis.tvalid && in_axis.tready) begin // if (rst)
         in_tdata_reg <= in_axis.tdata;

         case (header_ram_addr)
           // Pipelined, so nothing to look at first cycle.
           // Reset all the flags here.
           0: begin
              is_eth_dst_addr <= 1'b0;
              is_eth_broadcast <= 1'b0;
              is_eth_multicast <= 1'b0;
              is_eth_type_ipv4 <= 1'b0;
              is_ipv4_dst_addr <= 1'b0;
              is_ipv4_proto_udp <= 1'b0;
              is_ipv4_proto_icmp <= 1'b0;
              is_udp_dst_ports <= 0;
              is_icmp_no_fwd <= 0;
           end
           1: begin
              // Looking at upper 16bits of MAC Dst address
              // Are they all 0xffff?
              if (in_tdata_reg[15:0] == 16'hFFFF)
                is_eth_broadcast <= 1'b1;
              // Is LSB of first Octet set? TODO: Verify this is the correct bit with endianness shinanigans
              if (in_tdata_reg[8] == 1'b1)
                is_eth_multicast <= 1'b1;
              // Do upper 16bits of MAC Dst match my MAC?
              if (in_tdata_reg[15:0] == csr_mac[47:32])
                is_eth_dst_addr <= 1'b1;
           end
           2: begin
              //  Looking at lower 32bits of MAC Dst address
              // Are they all 0xffff_ffff?
              if (is_eth_broadcast && (in_tdata_reg[63:32] == 32'hFFFFFFFF))
                is_eth_broadcast <= 1'b1;
              else
                is_eth_broadcast <= 1'b0;
              // Do lower 32bits of MAC Dst match my MAC?
              if (is_eth_dst_addr && (in_tdata_reg[63:32] == csr_mac[31:0]))
                is_eth_dst_addr <= 1'b1;
              else
                is_eth_dst_addr <= 1'b0;
           end // case: 2
           3: begin
              // Look at Ethertype for IPv4 magic number
              if (in_tdata_reg[47:32] == 16'h0800)
                is_eth_type_ipv4 <= 1'b1;
           end
           4: begin
              // Look at protocol encapsulated by IPv4
              // Is it UDP?
              if ((in_tdata_reg[23:16] == 8'h11) && is_eth_type_ipv4)
                is_ipv4_proto_udp <= 1'b1;
              // Is it ICMP?
              if ((in_tdata_reg[23:16] == 8'h01) && is_eth_type_ipv4)
                is_ipv4_proto_icmp <= 1'b1;
           end
           5: begin
              // Look at IP DST Address.
              if ((in_tdata_reg[31:0] == csr_ip[31:0]) && is_eth_type_ipv4)
                is_ipv4_dst_addr <= 1'b1;
           end
           6: begin
              // Look at UDP dest port. Is it a match for one of mine?
              if ((in_tdata_reg[47:32] == csr_udp0[15:0]) && is_ipv4_proto_udp)
                is_udp_dst_ports[0] <= 1'b1;
              if ((in_tdata_reg[47:32] == csr_udp1[15:0]) && is_ipv4_proto_udp)
                is_udp_dst_ports[1] <= 1'b1;
           end
           7: begin
              // Nothing fixed pattern or discerning in L5 for DRaT that is a 100% ID for the protocol.
           end
           8: begin
              // Nothing fixed pattern or discerning in L5 for DRaT that is a 100% ID for the protocol.
           end
         endcase // case (header_ram_addr)
      end // if (in_axis.tvalid && in_axis.tready)
   end // always_ff @ (posedge clk)

   //---------------------------------------------------------
   // Egress Interface muxing
   //---------------------------------------------------------

   always_comb begin
      out_axis.tready =
                       (state == DROP_PACKET) ||
                       ((state == FORWARD_0) && out0_pre_axis.tready) ||
                       ((state == FORWARD_1) && out1_pre_axis.tready) ||
                       ((state == FORWARD_0_AND_1) && out0_pre_axis.tready && out1_pre_axis.tready);


      out_axis.tvalid =
                        ((state == FORWARD_0) ||
                         (state == FORWARD_1) ||
                         (state == FORWARD_0_AND_1) ||
                         (state == DROP_PACKET)) && (!fwd_input || in_axis.tvalid);

      {out_axis.tlast,out_axis.tdata} = fwd_input ?  {in_axis.tlast,in_axis.tdata} : header_ram[header_ram_addr];

      in_axis.tready = (state == WAIT_PACKET) ||
                       (state == READ_HEADER) ||
                       (out_axis.tready && fwd_input);

   end // always_comb

   //----------------------------------------------------------------------
   //
   // Because we can forward to both egress ports concurrently
   // we have to make sure both can accept data in the same cycle.
   // This makes it possible for either destination to block the other.
   // Make sure (both) destination(s) can accept data before passing it.
   //
   //----------------------------------------------------------------------
   always_comb begin
      out0_pre_axis.tvalid = out_axis.tvalid &&
                             ((state == FORWARD_0) ||
                              ((state == FORWARD_0_AND_1) && out1_pre_axis.tready));

      out1_pre_axis.tvalid = out_axis.tvalid &&
                             ((state == FORWARD_1) ||
                              ((state == FORWARD_0_AND_1) && out0_pre_axis.tready));

      {out0_pre_axis.tlast, out0_pre_axis.tdata} = {out_axis.tlast, out_axis.tdata};

      {out1_pre_axis.tlast, out1_pre_axis.tdata} = {out_axis.tlast, out_axis.tdata};

   end // always_comb

   //---------------------------------------------------------
   // Egress FIFO's
   //---------------------------------------------------------
   // These FIFO's have to be fairly large to prevent any egress
   // port from backpressuring the input state machine.
   //
   axis_fifo_wrapper #(.SIZE(10))
   axis_fifo_out0 (
                   .clk(clk),
                   .rst(rst),
                   .in_axis(out0_pre_axis),
                   .out_axis(out0_axis),
                   .space(),
                   .occupied()
                   );

   axis_fifo_wrapper #(.SIZE(10))
   axis_fifo_out1 (
                   .clk(clk),
                   .rst(rst),
                   .in_axis(out1_pre_axis),
                   .out_axis(out1_axis),
                   .space(),
                   .occupied()
                   );


endmodule // eth_classifier_2_egress

