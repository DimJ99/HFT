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
    typedef enum logic [1:0] {START, PARSE, HALF, BUFF} state_t;

    state_t nstate, state; 
    logic [7:0] headl, nheadl;

        always_ff @( posedge clk or negedge nrst ) begin
        if (!nrst) begin
        state <= START; 
        end else begin
        state <= nstate;
        end
    end
    always_comb begin      
    case (nstate)
    START: nstate = PARSE;
    PARSE: if (headl < 6) nstate = BUFF;
    if (headl == 7) nstate = HALF;
    if (headl == 6) nstate = START;  
    HALF: nstate = PARSE;
    BUFF: nstate = PARSE;
    endcase
    end


    always_ff @( posedge clk or negedge nrst ) begin
        if (!nrst) begin
        headl <= 0; 
        end else begin
        headl <= nheadlen;
        end
    end
    always_comb begin
        nheadl = 0;   
        if (headl < 8) nheadl =  s_axis.tdata[(63 - (headl*8)) -: 16]  - 6+headl;
        if (headl >= 8) nheadl = headl - 8;  
    end
     always_ff @( posedge clk or negedge nrst ) begin
        if (!nrst) begin
        headl <= 0; 
        end else begin
        axis_if.parsed.type <= s_axis.tdata[headl+:16];
        end
    end

// TODO STRUCT: 2 CONCURRENT STORAGE ELEMENTS
// TODO PACKET PARSING 

    assign s_axis.tready = 1'b1;

endmodule
