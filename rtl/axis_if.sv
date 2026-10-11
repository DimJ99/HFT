interface axis_if #(
    parameter int DATA_W = 64,
    parameter int USER_W = 1
) (
    input logic clk,
    input logic nrst
);
    localparam int KEEP_W = DATA_W / 8;

    logic [DATA_W-1:0] tdata;
    logic [KEEP_W-1:0] tkeep;
    logic              tvalid;
    logic              tlast;
    logic [USER_W-1:0] tuser;
    logic              tready;
    parsed_t           out;

    // Upstream side: drives the data, receives backpressure.
    modport source (input clk, nrst, tready, output tdata, tkeep, tvalid, tlast, tuser);
    // Downstream side: receives the data, drives backpressure.
    modport sink   (input clk, nrst, tdata, tkeep, tvalid, tlast, tuser, output tready, out);
    // Passive observer (assertions, debug).
    modport monitor(input clk, nrst, tdata, tkeep, tvalid, tlast, tuser, tready);

endinterface
/* verilator lint_on UNUSEDSIGNAL */
