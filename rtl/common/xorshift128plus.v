module Xorshift128plus #(
                         parameter SEED = 0)
    (
     input  wire        clk,
     input  wire        i_rst,
     input  wire        i_enable,
     output wire [63:0] o_out);

    wire [63:0] t0;
    wire [63:0] t1;
    wire [63:0] next_s1;

    reg  [63:0] s0;
    reg  [63:0] s1;

    localparam RAND_SEED0 = 64'he220a8397b1dcdaf;
    localparam RAND_SEED1 = 64'h6e789e6aa1b965f4;

    assign o_out = next_s1 + t0;

    assign t0      = s1;
    assign t1      = s0 ^ (s0 << 23);
    assign next_s1 = t1 ^ t0 ^ (t1 >> 17) ^ (t0 >> 26);

    always @(posedge clk) begin
        if (i_rst) begin
            s0 <= RAND_SEED0 + SEED;
            s1 <= RAND_SEED1 + SEED;
        end else begin
            if (i_enable) begin
                s0 <= s1;
                s1 <= next_s1;
            end
        end
    end
endmodule
