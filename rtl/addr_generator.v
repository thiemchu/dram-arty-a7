module AddrGenerator #(
                       // ADDR_WIDTH must not be greater than 67
                       parameter ADDR_WIDTH = 27)
    (
     input  wire                    clk,
     input  wire                    i_rst,
     input  wire                    i_wen,
     input  wire                    i_ren,
     output wire [ADDR_WIDTH-1 : 0] o_waddr,
     output wire [ADDR_WIDTH-1 : 0] o_raddr);

    localparam RAND_SEED = 20200826;

    wire [63:0] waddr;
    wire [63:0] raddr;

    assign o_waddr = {waddr[ADDR_WIDTH-4 : 0], 3'b000};
    assign o_raddr = {raddr[ADDR_WIDTH-4 : 0], 3'b000};

    Xorshift128plus #(
                      .SEED(RAND_SEED))
    rand_waddr (
                .clk(clk),
                .i_rst(i_rst),
                .i_enable(i_wen),
                .o_out(waddr));

    Xorshift128plus #(
                      .SEED(RAND_SEED))
    rand_raddr (
                .clk(clk),
                .i_rst(i_rst),
                .i_enable(i_ren),
                .o_out(raddr));

endmodule
