module DataGenerator #(
                       parameter DATA_WIDTH = 128)
    (
     input  wire                    clk,
     input  wire                    i_rst,
     input  wire                    i_get_write_data,
     input  wire                    i_get_validation_data,
     output wire [DATA_WIDTH-1 : 0] o_write_data,
     output wire [DATA_WIDTH-1 : 0] o_validation_data);

    localparam RAND_SEED = 2020;

    genvar genvar_i;

    wire [63:0] write_data[DATA_WIDTH/64-1 : 0];
    wire [63:0] validation_data[DATA_WIDTH/64-1 : 0];

    generate
        for (genvar_i = 0; genvar_i < DATA_WIDTH/64; genvar_i = genvar_i + 1) begin
            assign o_write_data[genvar_i*64 +: 64] = write_data[genvar_i];
            assign o_validation_data[genvar_i*64 +: 64] = validation_data[genvar_i];

            Xorshift128plus #(
                              .SEED(RAND_SEED+genvar_i))
            rand_write (
                        .clk(clk),
                        .i_rst(i_rst),
                        .i_enable(i_get_write_data),
                        .o_out(write_data[genvar_i]));

            Xorshift128plus #(
                              .SEED(RAND_SEED+genvar_i))
            rand_validation (
                             .clk(clk),
                             .i_rst(i_rst),
                             .i_enable(i_get_validation_data),
                             .o_out(validation_data[genvar_i]));
        end
    endgenerate

endmodule
