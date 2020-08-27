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

    reg  [ADDR_WIDTH-4 : 0] waddr;
    reg  [ADDR_WIDTH-4 : 0] raddr;

    assign o_waddr = {waddr, 3'b000};
    assign o_raddr = {raddr, 3'b000};

    always @(posedge clk) begin
        if (i_rst) begin
            waddr <= 0;
            raddr <= 0;
        end else begin
            if (i_wen) begin
                waddr <= waddr + 1;
            end
            if (i_ren) begin
                raddr <= raddr + 1;
            end
        end
    end

endmodule
