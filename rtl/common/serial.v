// b = baud rate (in megabaud - MBd)
// f = frequency of clk (in MHz)
// SERIAL_WCNT = f/b
// e.g. b = 1, f = 100 -> SERIAL_WCNT = 100/1 = 100
`define SERIAL_WCNT 100 // 1MBd UART wait count

`define SS_SER_WAIT 'd0 // RS232C deserializer, State WAIT
`define SS_SER_RCV0 'd1 // RS232C deserializer, State Receive 0th bit
                        // States Receive 1st bit to 7th bit are not used
`define SS_SER_DONE 'd9 // RS232C deserializer, State DONE

/********************************************************************************/
module UartTx (
               input  wire       clk,
               input  wire       i_rst,
               input  wire [7:0] i_data,
               input  wire       i_wen,
               output reg        o_txd,
               output reg        o_ready);

    reg [8:0]  cmd;
    reg [11:0] waitnum;
    reg [3:0]  cnt;

    always @(posedge clk) begin
        if (i_rst) begin
            o_txd   <= 1'b1;
            o_ready <= 1'b1;
            cmd     <= 9'h1ff;
            waitnum <= 0;
            cnt     <= 0;
        end else if (o_ready) begin
            o_txd   <= 1'b1;
            waitnum <= 0;
            if (i_wen) begin
                o_ready <= 1'b0;
                cmd     <= {i_data, 1'b0};
                cnt     <= 10;
            end
        end else if (waitnum >= `SERIAL_WCNT) begin
            o_txd   <= cmd[0];
            o_ready <= (cnt == 1);
            cmd     <= {1'b1, cmd[8:1]};
            waitnum <= 1;
            cnt     <= cnt - 1;
        end else begin
            waitnum <= waitnum + 1;
        end
    end
endmodule

/********************************************************************************/
module UartRx (
               input  wire       clk,
               input  wire       i_rst,
               input  wire       i_rxd,
               output reg  [7:0] o_data,
               output reg        o_en);

    reg  [3:0]  stage;
    reg  [12:0] cnt;       // counter to latch D0, D1, ..., D7
    reg  [11:0] cnt_start; // counter to detect the Start Bit

    wire [12:0] waitcnt;

    assign waitcnt = `SERIAL_WCNT;

    always @(posedge clk) begin
        if (i_rst) begin
            cnt_start <= 0;
        end else begin
            cnt_start <= (i_rxd) ? 0 : cnt_start + 1;
        end
    end

    always @(posedge clk) begin
        if(i_rst) begin
            o_en   <= 0;
            stage  <= `SS_SER_WAIT;
            cnt    <= 1;
            o_data <= 0;
        end else if (stage == `SS_SER_WAIT) begin // detect the Start Bit
            o_en  <= 0;
            stage <= (cnt_start == (waitcnt >> 1)) ? `SS_SER_RCV0 : stage;
        end else begin
            if (cnt != waitcnt) begin
                cnt  <= cnt + 1;
                o_en <= 0;
            end else begin // receive 1bit data
                stage  <= (stage == `SS_SER_DONE) ? `SS_SER_WAIT : stage + 1;
                o_en   <= (stage == 8)  ? 1 : 0;
                o_data <= {i_rxd, o_data[7:1]};
                cnt    <= 1;
            end
        end
    end
endmodule
