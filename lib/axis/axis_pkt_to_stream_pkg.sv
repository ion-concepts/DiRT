//-----------------------------------------------------------------------------
// File:    axis_pkt_to_stream_pkg.sv.sv
//
// Description:
// Sub-system wide shared definitions for axis_pkt_to_stream
//
//-----------------------------------------------------------------------------

package axis_pkt_to_stream_pkg;
    import drat_protocol::*;
    typedef struct packed
                   {
                       logic odd;
                       logic async;
                       logic eob;
                       logic eop;
                       logic [7:0] seq_num;
                       logic [31:0] flow_id;
                       logic [63:0] timestamp;
                       drat_protocol::int16_complex_t samples;
                   } pkt_to_stream_fifo_t;

endpackage : axis_pkt_to_stream_pkg
