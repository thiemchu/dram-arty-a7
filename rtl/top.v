module Top #(
             parameter DDR3_DQ_WIDTH   = 16,
             parameter DDR3_DQS_WIDTH  = 2,
             parameter DDR3_ADDR_WIDTH = 14,
             parameter DDR3_BA_WIDTH   = 3,
             parameter DDR3_DM_WIDTH   = 2,
             parameter APP_ADDR_WIDTH  = 28,
             parameter APP_CMD_WIDTH   = 3,
             parameter APP_DATA_WIDTH  = 128,
             parameter APP_MASK_WIDTH  = 16)
    (
     // input clock (100MHz), reset (active-low) ports
     input  wire                         clk_in,
     input  wire                         rstx_in,
     // dram interface ports
     inout  wire [DDR3_DQ_WIDTH-1 : 0]   ddr3_dq,
     inout  wire [DDR3_DQS_WIDTH-1 : 0]  ddr3_dqs_n,
     inout  wire [DDR3_DQS_WIDTH-1 : 0]  ddr3_dqs_p,
     output wire [DDR3_ADDR_WIDTH-1 : 0] ddr3_addr,
     output wire [DDR3_BA_WIDTH-1 : 0]   ddr3_ba,
     output wire                         ddr3_ras_n,
     output wire                         ddr3_cas_n,
     output wire                         ddr3_we_n,
     output wire                         ddr3_reset_n,
     output wire [0:0]                   ddr3_ck_p,
     output wire [0:0]                   ddr3_ck_n,
     output wire [0:0]                   ddr3_cke,
     output wire [0:0]                   ddr3_cs_n,
     output wire [DDR3_DM_WIDTH-1 : 0]   ddr3_dm,
     output wire [0:0]                   ddr3_odt,
     // uart tx port
     output wire                         uart_txd);

    localparam STATE_CALIB      = 2'b00;
    localparam STATE_WRITE_DRAM = 2'b01;
    localparam STATE_READ_DRAM  = 2'b10;
    localparam STATE_WAIT       = 2'b11;

    localparam SUB_APP_ADDR_WIDTH = 19;
    localparam SUB_TX_ADDR = {1'b1, {(SUB_APP_ADDR_WIDTH-1){1'b0}}};

    wire                        clk;
    wire                        rst;

    wire                        clk_166_67_mhz;
    wire                        clk_200_mhz;
    wire                        dram_rst;
    wire                        dram_rstx_async;
    reg                         dram_rst_sync1;
    reg                         dram_rst_sync2;
    wire                        locked;

    wire                        dram_ren;
    wire                        dram_wen;
    wire [APP_ADDR_WIDTH-2 : 0] dram_addr;
    wire [APP_DATA_WIDTH-1 : 0] dram_din;
    wire [APP_MASK_WIDTH-1 : 0] dram_mask;
    wire                        dram_init_calib_complete;
    wire [APP_DATA_WIDTH-1 : 0] dram_dout;
    wire                        dram_dout_valid;
    wire                        dram_busy;

    wire                        user_design_busy;

    wire [APP_ADDR_WIDTH-2 : 0] dram_waddr;
    wire [APP_ADDR_WIDTH-2 : 0] dram_raddr;

    wire [APP_DATA_WIDTH-1 : 0] validation_data;

    reg  [APP_ADDR_WIDTH-5 : 0] num_dram_rws;
    reg  [APP_ADDR_WIDTH-5 : 0] num_dram_douts;

    reg  [1:0]                  state;
    reg                         flag_mismatch;

    reg                         uart_en;
    reg  [APP_DATA_WIDTH-1 : 0] uart_data;
    reg                         uart_hex;

    wire [APP_DATA_WIDTH-1 : 0] wr_msg;
    wire [APP_DATA_WIDTH-1 : 0] rd_msg;
    wire [APP_DATA_WIDTH-1 : 0] passed_msg;
    wire [APP_DATA_WIDTH-1 : 0] failed_msg;

    wire [SUB_APP_ADDR_WIDTH-1 : 0] sub_num_dram_rws;
    wire [SUB_APP_ADDR_WIDTH-1 : 0] sub_num_dram_douts;

    // write message: "WRITE:\n" (space padding before the line break)
    assign wr_msg = {8'h0A, 8'h0D, {(APP_DATA_WIDTH/8-8){8'h20}},
                     8'h3A, 8'h45, 8'h54, 8'h49, 8'h52, 8'h57};
    // read message: "\nREAD:\n" (space padding before the second line break)
    assign rd_msg = {8'h0A, 8'h0D, {(APP_DATA_WIDTH/8-9){8'h20}},
                     8'h3A, 8'h44, 8'h41, 8'h45, 8'h52, 8'h0A, 8'h0D};
    // test passed: "\n\nPASSED!\n" (space padding before the third line break)
    assign passed_msg = {8'h0A, 8'h0D, {(APP_DATA_WIDTH/8-13){8'h20}},
                         8'h21, 8'h44, 8'h45, 8'h53, 8'h53, 8'h41, 8'h50,
                         8'h0A, 8'h0D, 8'h0A, 8'h0D};
    // test failed: "\n\nFAILED!\n" (space padding before the third line break)
    assign failed_msg = {8'h0A, 8'h0D, {(APP_DATA_WIDTH/8-13){8'h20}},
                         8'h21, 8'h44, 8'h45, 8'h4C, 8'h49, 8'h41, 8'h46,
                         8'h0A, 8'h0D, 8'h0A, 8'h0D};

    assign sub_num_dram_rws = num_dram_rws[SUB_APP_ADDR_WIDTH-1 : 0];
    assign sub_num_dram_douts = num_dram_douts[SUB_APP_ADDR_WIDTH-1 : 0];

    assign dram_rstx_async = rstx_in & locked;
    assign dram_rst = dram_rst_sync2;

    always @(posedge clk_166_67_mhz or negedge dram_rstx_async) begin
        if (!dram_rstx_async) begin
            dram_rst_sync1 <= 1'b1;
            dram_rst_sync2 <= 1'b1;
        end else begin
            dram_rst_sync1 <= 1'b0;
            dram_rst_sync2 <= dram_rst_sync1;
        end
    end

    clk_wiz_1 dram_clkgen (
                           .clk_in1(clk_in),
                           .resetn(rstx_in),
                           .clk_out1(clk_166_67_mhz),
                           .clk_out2(clk_200_mhz),
                           .locked(locked));

    assign dram_ren  = (state == STATE_READ_DRAM && !dram_busy);
    assign dram_wen  = (state == STATE_WRITE_DRAM && !dram_busy);
    assign dram_addr = (state == STATE_WRITE_DRAM)? dram_waddr : dram_raddr;
    assign dram_mask = {(APP_MASK_WIDTH){1'b0}}; // no masking
    // in this test, user design can always accept data from dram
    assign user_design_busy = 1'b0;

    DRAM #(
           .DDR3_DQ_WIDTH(DDR3_DQ_WIDTH),
           .DDR3_DQS_WIDTH(DDR3_DQS_WIDTH),
           .DDR3_ADDR_WIDTH(DDR3_ADDR_WIDTH),
           .DDR3_BA_WIDTH(DDR3_BA_WIDTH),
           .DDR3_DM_WIDTH(DDR3_DM_WIDTH),
           .APP_ADDR_WIDTH(APP_ADDR_WIDTH),
           .APP_CMD_WIDTH(APP_CMD_WIDTH),
           .APP_DATA_WIDTH(APP_DATA_WIDTH),
           .APP_MASK_WIDTH(APP_MASK_WIDTH))
    dram (
          // input clock (166.67MHz),
          // reference clock (200MHz),
          // reset (active-high)
          .sys_clk(clk_166_67_mhz),
          .ref_clk(clk_200_mhz),
          .sys_rst(dram_rst),
          // dram interface signals
          .ddr3_dq(ddr3_dq),
          .ddr3_dqs_n(ddr3_dqs_n),
          .ddr3_dqs_p(ddr3_dqs_p),
          .ddr3_addr(ddr3_addr),
          .ddr3_ba(ddr3_ba),
          .ddr3_ras_n(ddr3_ras_n),
          .ddr3_cas_n(ddr3_cas_n),
          .ddr3_we_n(ddr3_we_n),
          .ddr3_reset_n(ddr3_reset_n),
          .ddr3_ck_p(ddr3_ck_p),
          .ddr3_ck_n(ddr3_ck_n),
          .ddr3_cke(ddr3_cke),
          .ddr3_cs_n(ddr3_cs_n),
          .ddr3_dm(ddr3_dm),
          .ddr3_odt(ddr3_odt),
          // output clock and reset (active-high) signals for user design
          .o_clk(clk),
          .o_rst(rst),
          // user design interface signals
          .i_ren(dram_ren),
          .i_wen(dram_wen),
          .i_addr(dram_addr),
          .i_data(dram_din),
          .i_mask(dram_mask),
          .i_busy(user_design_busy),
          .o_init_calib_complete(dram_init_calib_complete),
          .o_data(dram_dout),
          .o_data_valid(dram_dout_valid),
          .o_busy(dram_busy));

    DataGenerator #(
                    .DATA_WIDTH(APP_DATA_WIDTH))
    dgen (
          .clk(clk),
          .i_rst(rst),
          .i_get_write_data(dram_wen),
          .i_get_validation_data(dram_dout_valid),
          .o_write_data(dram_din),
          .o_validation_data(validation_data));

    AddrGenerator #(
                    .ADDR_WIDTH(APP_ADDR_WIDTH-1))
    agen (
          .clk(clk),
          .i_rst(rst),
          .i_wen(dram_wen),
          .i_ren(dram_ren),
          .o_waddr(dram_waddr),
          .o_raddr(dram_raddr));

    DataTransmitter #(
                      .DATA_WIDTH(APP_DATA_WIDTH))
    tx (
        .clk(clk),
        .i_rst(rst),
        .i_en(uart_en),
        .i_data(uart_data),
        .i_hex(uart_hex),
        .o_txd(uart_txd));

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_CALIB;
            num_dram_rws <= 0;
            num_dram_douts <= 0;
            uart_en <= 0;
            uart_data <= 0;
            uart_hex <= 0;
            flag_mismatch <= 0;
        end else begin
            uart_en <= 0;
            case (state)
                STATE_CALIB: begin
                    if (dram_init_calib_complete) begin
                        state <= STATE_WRITE_DRAM;
                        uart_en <= 1;
                        uart_data <= wr_msg;
                        uart_hex <= 0;
                    end
                end
                STATE_WRITE_DRAM: begin
                    if (dram_wen) begin
                        num_dram_rws <= num_dram_rws + 1;
                        if (sub_num_dram_rws == SUB_TX_ADDR) begin
                            uart_en <= 1;
                            uart_data <= dram_din;
                            uart_hex <= 1;
                        end
                        if (num_dram_rws == {(APP_ADDR_WIDTH-1-3){1'b1}}) begin
                            state <= STATE_READ_DRAM;
                            uart_en <= 1;
                            uart_data <= rd_msg;
                            uart_hex <= 0;
                        end
                    end
                end
                STATE_READ_DRAM: begin
                    if (dram_ren) begin
                        num_dram_rws <= num_dram_rws + 1;
                        if (num_dram_rws == {(APP_ADDR_WIDTH-1-3){1'b1}}) begin
                            state <= STATE_WAIT;
                        end
                    end
                    if (dram_dout_valid) begin
                        num_dram_douts <= num_dram_douts + 1;
                        if (sub_num_dram_douts == SUB_TX_ADDR) begin
                            uart_en <= 1;
                            uart_data <= dram_dout;
                            uart_hex <= 1;
                        end
                        if (dram_dout != validation_data) begin
                            flag_mismatch <= 1;
                        end
                    end
                end
                STATE_WAIT: begin
                    if (dram_dout_valid) begin
                        num_dram_douts <= num_dram_douts + 1;
                        if (sub_num_dram_douts == SUB_TX_ADDR) begin
                            uart_en <= 1;
                            uart_data <= dram_dout;
                            uart_hex <= 1;
                        end
                        if (dram_dout != validation_data) begin
                            flag_mismatch <= 1;
                        end
                        if (num_dram_douts == {(APP_ADDR_WIDTH-1-3){1'b1}}) begin
                            uart_en <= 1;
                            uart_hex <= 0;
                            if (flag_mismatch || dram_dout != validation_data) begin
                                uart_data <= failed_msg;
                            end else begin
                                uart_data <= passed_msg;
                            end
                            // state <= STATE_WRITE_DRAM; // restart the test with different data
                        end
                    end
                end
            endcase
        end
    end

endmodule
