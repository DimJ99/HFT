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

    logic [7:0] headl, nheadl, upper;


    logic half;
    always_ff @( posedge clk or negedge nrst ) begin
        if (!nrst) begin
        half <= 0; 
        upper <= 0; 
        end else begin
        half <= headl == 7 ? 1 : 0;
        upper <= headl == 7 ? s_axis.tdata[63:55] :0 ;
        end
    end
    always_ff @( posedge clk or negedge nrst ) begin
        if (!nrst) begin
        headl <= 0; 
        end else begin
        headl <= nheadl;
        end
    end
    always_comb begin
        nheadl = 0;   
        if (headl < 8 && !(headl == 7)) nheadl =  {s_axis.tdata[headl+:8],s_axis.tdata[headl+8+:8]} -6+headl;
        if (headl >= 8) nheadl = headl - 8;  
        if (headl == 7) nheadl = 0;
        if (half == 1) nheadl = {upper, s_axis.tdata[headl+:8]} - 7;
    end

    logic [49:0] [7:0] stored, ready;
    logic [7:0] [7:0]sbuffer;      
    logic [7:0] lane0,lane1,lane2,lane3,lane4,lane5,lane6,lane7; 
    logic merge;
    always_comb begin 
    lane0 = s_axis.tdata[7:0];
    lane1 = s_axis.tdata[15:8];
    lane2 = s_axis.tdata[23:16];
    lane3 = s_axis.tdata[31:24];
    lane4 = s_axis.tdata[39:32];
    lane5 = s_axis.tdata[47:40];
    lane6 = s_axis.tdata[55:48];
    lane7 = s_axis.tdata[63:56];
    end

     always_ff @( posedge clk or negedge nrst ) begin
        if (!nrst) begin
        stored <= 0;
        end else begin
        if (headl > 7)begin
        stored[headl] <= lane0;
        stored[headl-1] <= lane1;
        stored[headl-2] <= lane2;
        stored[headl-3] <= lane3; 
        stored[headl-4] <= lane4;
        stored[headl-5] <= lane5;
        stored[headl-6] <= lane6;
        stored[headl-7] <= lane7; 
        end
        if (headl == 7) begin
        stored[headl] <= lane0;
        stored[headl-1] <= lane1;
        stored[headl-2] <= lane2;
        stored[headl-3] <= lane3; 
        stored[headl-4] <= lane4;
        stored[headl-5] <= lane5;
        stored[headl-6] <= lane6;
        end
        if (headl == 6)begin
        stored[headl] <= lane0;
        stored[headl-1] <= lane1;
        stored[headl-2] <= lane2;
        stored[headl-3] <= lane3; 
        stored[headl-4] <= lane4;
        stored[headl-5] <= lane5;
        end
        if (headl == 5) begin
        stored[headl] <= lane0;
        stored[headl-1] <= lane1;
        stored[headl-2] <= lane2;
        stored[headl-3] <= lane3; 
        stored[headl-4] <= lane4;
        end
        if (headl == 4)begin
        stored[headl] <= lane0;
        stored[headl-1] <= lane1;
        stored[headl-2] <= lane2;
        stored[headl-3] <= lane3; 
        end
        if (headl == 3) begin
        stored[headl] <= lane0;
        stored[headl-1] <= lane1;
        stored[headl-2] <= lane2;
        end
        if (headl == 2) begin
        stored[headl] <= lane0;
        stored[headl-1] <= lane1;
        end
        if (headl == 1) begin
        stored[headl] <= lane0;
        end
        if (headl == 0 && !half) begin
        stored[headl] <= lane2;
        stored[headl-1] <= lane3; 
        stored[headl-2] <= lane4;
        stored[headl-3] <= lane5;
        stored[headl-4] <= lane6;
        stored[headl-5] <= lane7; 
        end
        if (half) begin
        stored[headl] <= lane1;
        stored[headl-1] <= lane2; 
        stored[headl-2] <= lane3;
        stored[headl-3] <= lane4;
        stored[headl-4] <= lane5;
        stored[headl-5] <= lane6;
        stored[headl-6] <= lane6; 
        end
    end
     end


    always_ff @( posedge clk or negedge nrst ) begin
        if (!nrst) begin
        stored <= 0; 
        end else begin
        stored <= 0;
        if (headl == 5) begin
        stored[0] <= lane7; 
        merge <= 1; 
        end if (headl == 4) begin
        stored[0] <= lane6;
        stored[1] <= lane7; 
        merge <= 1; 
        end if (headl == 3) begin
        stored[0] <= lane5;
        stored[1] <= lane6;
        stored[2] <= lane7;
        merge <= 1; 
        end if (headl == 2) begin
        stored[0] <= lane4;
        stored[1] <= lane5;
        stored[2] <= lane6; 
        stored[3] <= lane7;
        merge <= 1;
        end if (headl == 1) begin
        stored[0] <= lane3;
        stored[1] <= lane4;
        stored[2] <= lane5; 
        stored[3] <= lane6;
        stored[4] <= lane7;
        merge <= 1;
        end 
    end
    end


// TODO Actually add final and decode struct

    assign s_axis.tready = 1'b1;

endmodule
