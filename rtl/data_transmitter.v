module DataTransmitter #(
                         // DATA_WIDTH must be a multiple of 8
                         parameter DATA_WIDTH = 128)
    (
     input  wire                    clk,
     input  wire                    i_rst,
     input  wire                    i_en,
     input  wire [DATA_WIDTH-1 : 0] i_data,
     input  wire                    i_hex,
     output wire                    o_txd);

    localparam UART_IDLE = 1'b0;
    localparam UART_TX   = 1'b1;

    // CNT_WIDTH must be greater than 1+log2(DATA_WIDTH/4)
    localparam CNT_WIDTH = 7;

    reg                     uart_state;
    reg  [7:0]              uart_data;
    reg  [CNT_WIDTH-1 : 0]  uart_cnt;
    reg                     uart_en;
    reg  [DATA_WIDTH-1 : 0] data;
    reg                     hex;
    reg                     txd = 1'b1;

    wire                    tx_ready;
    wire                    txd_wire;

    assign o_txd = txd;

    UartTx send (
                 .clk(clk),
                 .i_rst(i_rst),
                 .i_data(uart_data),
                 .i_wen(uart_en),
                 .o_txd(txd_wire),
                 .o_ready(tx_ready));

    always @(posedge clk) begin
        if (i_rst) begin
            uart_state <= UART_IDLE;
            uart_data <= 0;
            uart_cnt <= 0;
            uart_en <= 0;
            data <= 0;
            hex <= 0;
            txd <= 1;
        end else begin
            txd <= txd_wire;
            case (uart_state)
                UART_IDLE: begin
                    uart_state <= UART_IDLE;
                    uart_data <= 8'hFF;
                    uart_cnt <= 0;
                    uart_en <= 0;
                    data <= 0;
                    hex <= 0;
                    if (i_en) begin
                        uart_state <= UART_TX;
                        data <= i_data;
                        hex <= i_hex;
                    end
                end
                UART_TX: begin
                    uart_state <= UART_TX;
                    if (tx_ready) begin
                        uart_cnt <= uart_cnt + 1;
                        if (hex) begin
                            if (uart_cnt == 1 + DATA_WIDTH/4) begin
                                uart_state <= UART_IDLE;
                                uart_data <= 8'hFF;
                                uart_cnt <= 0;
                                uart_en <= 0;
                                data <= 0;
                            end else begin
                                uart_en <= 1;
                                if (uart_cnt == DATA_WIDTH/4) begin
                                    // 8'h20: space
                                    uart_data <= 8'h20;
                                end else begin
                                    if (data[DATA_WIDTH-1 : DATA_WIDTH-4] < 10) begin
                                        // 8'h30: '0'
                                        uart_data <= data[DATA_WIDTH-1 : DATA_WIDTH-4] + 8'h30;
                                    end else begin
                                        // 8'h41: 'A'
                                        uart_data <= data[DATA_WIDTH-1 : DATA_WIDTH-4] - 10 + 8'h41;
                                    end
                                    data <= {data[DATA_WIDTH-5 : 0], 4'h0};
                                end
                            end
                        end else begin
                            if (uart_cnt == DATA_WIDTH/8) begin
                                uart_state <= UART_IDLE;
                                uart_data <= 8'hFF;
                                uart_cnt <= 0;
                                uart_en <= 0;
                                data <= 0;
                            end else begin
                                uart_en <= 1;
                                uart_data <= data[7:0];
                                data <= {8'h00, data[DATA_WIDTH-1 : 8]};
                            end
                        end
                    end
                end
            endcase
        end
    end

endmodule
