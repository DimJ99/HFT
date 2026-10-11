// tdata	64	8 bytes of the frame per clock
// tkeep	8	Which bytes in tdata are valid (1 bit per byte). All ones except possibly on the last beat.
// tvalid	1	Data on this cycle is real
// tlast	1	This is the final beat of the frame
// tuser	1+	Usually a bad-frame flag (CRC error). If set on the tlast beat, discard the frame.
// tready	1	Your backpressure signal. The RX side of most MACs ignores it or has no tready at all, because you can't pause the wire. Your parser must keep up at line rate.
module itch_parser (
    input logic clk, input logic nrst,
    axis_if.sink s_axis
);
    localparam MAX_PACK = $clog2 (50*8);

    logic [7:0] lpntr; 
    logic [MAX_PACK:0] len, ilen, nlen, plen;

    typedef enum logic [1:0] {GET, PARSE, HALF} state_t;

    state_t state, nstate;
    always_ff @(posedge clk or negedge nrst) begin
        if(!nrst) begin
        state <= GET;
        end else 
        state <= nstate;
    end

    always_comb begin
    case (nstate) 
    GET: nstate = PARSE;
    PARSE: if (lpntr == 55) nstate = HALF;
    HALF: nstate = PARSE;
    default: nstate = GET;
    endcase
    end


    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
        len <= 0; 
        ilen <= 0;
        end else begin
        len <= len-64; 
        if (state == GET) len <= nlen - 48;
        if (s_axis.tlast) len <= nlen-(64 - lpntr+16);
        if (state == HALF) len <= nlen - 56;
        if ((lpntr == 55)) len = nlen;
        end
    end 


    always_comb begin
    lpntr = 0;
    nlen = (s_axis.tdata [lpntr+:8] + s_axis.tdata[(lpntr+8) +: 8]) * 8;
    if (s_axis.tlast) lpntr = len; 
    if (lpntr == 55) nlen = s_axis.tdata [lpntr+:8];
    if (state == HALF)nlen = ( len + s_axis.tdata [lpntr+:8])* 8;
    end


    
    always_comb begin // type
    s_axis.parsed.type =0;
    if (state = GET) axis_if.parsed.type = s_axis.tdata [(lpntr+16)+:8];
    if (s_axis.tlast) axis_if.parsed.type = s_axis.tdata [(lpntr+16)+:8];
    if (lpntr == 39) axis_if.parsed.type = s_axis.tdata [lpntr+:8];
    end


    always_comb begin //parsing
    
    end

// TODO STRUCT: 2 CONCURRENT STORAGE ELEMENTS
// TODO PACKET PARSING 

    assign s_axis.tready = 1'b1;

endmodule
