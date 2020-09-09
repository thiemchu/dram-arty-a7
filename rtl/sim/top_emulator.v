module Top;
    // DRAM_SIZE is in bytes;
    // DRAM_SIZE must be a multiple of
    // 16 bytes = 128 bits (APP_DATA_WIDTH)
    parameter DRAM_SIZE         = 1024*1024*4; // 4MB
    // only busrt length = 8 is supported
    parameter DRAM_BURST_LENGTH = 8;
    parameter APP_DATA_WIDTH    = 128;
    parameter APP_MASK_WIDTH    = 16;

    parameter APP_ADDR_WIDTH = $clog2((DRAM_SIZE * 8) / APP_DATA_WIDTH) +
                               $clog2(DRAM_BURST_LENGTH) + 1;

    localparam STATE_CALIB      = 2'b00;
    localparam STATE_WRITE_DRAM = 2'b01;
    localparam STATE_READ_DRAM  = 2'b10;
    localparam STATE_WAIT       = 2'b11;

    // in this test, DRAM_SIZE should be >= 512B
    // so that APP_ADDR_WIDTH >= 9
    localparam SUB_APP_ADDR_WIDTH = APP_ADDR_WIDTH - 8;
    localparam SUB_TX_ADDR = {1'b1, {(SUB_APP_ADDR_WIDTH-1){1'b0}}};

    reg                         clk = 0;
    reg                         rst;

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

    wire [SUB_APP_ADDR_WIDTH-1 : 0] sub_num_dram_rws;
    wire [SUB_APP_ADDR_WIDTH-1 : 0] sub_num_dram_douts;

    always #60 clk = ~clk;

    initial begin
        rst = 1;
        #120 rst = 0;
    end

    assign sub_num_dram_rws = num_dram_rws[SUB_APP_ADDR_WIDTH-1 : 0];
    assign sub_num_dram_douts = num_dram_douts[SUB_APP_ADDR_WIDTH-1 : 0];

    assign dram_ren  = (state == STATE_READ_DRAM && !dram_busy);
    assign dram_wen  = (state == STATE_WRITE_DRAM && !dram_busy);
    assign dram_addr = (state == STATE_WRITE_DRAM)? dram_waddr : dram_raddr;
    assign dram_mask = {(APP_MASK_WIDTH){1'b0}}; // no masking
    // in this test, user design can always accept data from dram
    assign user_design_busy = 1'b0;

    DRAM #(
           .DRAM_SIZE(DRAM_SIZE),
           .DRAM_BURST_LENGTH(DRAM_BURST_LENGTH),
           .APP_ADDR_WIDTH(APP_ADDR_WIDTH),
           .APP_DATA_WIDTH(APP_DATA_WIDTH),
           .APP_MASK_WIDTH(APP_MASK_WIDTH))
    dram (
          .clk(clk),
          .i_rst(rst),
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

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_CALIB;
            num_dram_rws <= 0;
            num_dram_douts <= 0;
            flag_mismatch <= 0;
        end else begin
            case (state)
                STATE_CALIB: begin
                    if (dram_init_calib_complete) begin
                        state <= STATE_WRITE_DRAM;
                        $display("WRITE:");
                    end
                end
                STATE_WRITE_DRAM: begin
                    if (dram_wen) begin
                        num_dram_rws <= num_dram_rws + 1;
                        if (sub_num_dram_rws == SUB_TX_ADDR) begin
                            $write("%H ", dram_din);
                        end
                        if (num_dram_rws == {(APP_ADDR_WIDTH-1-3){1'b1}}) begin
                            state <= STATE_READ_DRAM;
                            $write("\nREAD:\n");
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
                            $write("%H ", dram_dout);
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
                            $write("%H ", dram_dout);
                        end
                        if (dram_dout != validation_data) begin
                            flag_mismatch <= 1;
                        end
                        if (num_dram_douts == {(APP_ADDR_WIDTH-1-3){1'b1}}) begin
                            if (flag_mismatch || dram_dout != validation_data) begin
                                $write("\n\nFAILED!\n");
                            end else begin
                                $write("\n\nPASSED!\n");
                            end
                            $finish;
                            // state <= STATE_WRITE_DRAM; // restart the test with different data
                        end
                    end
                end
            endcase
        end
    end

endmodule
