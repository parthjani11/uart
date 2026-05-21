module u_xmit #(
    parameter integer WORD_LEN = 8
)(
    input  wire                  uart_clk,
    input  wire                  sys_rst_I,
    input  wire                  xmitH,
    input  wire [WORD_LEN-1:0]   xmit_dataH,
    output reg                   uart_XMIT_dataH,
    output reg                   xmit_doneH,
    output reg                   xmit_activeH
);

    localparam [1:0] IDLE  = 2'b00,
                     START = 2'b01,
                     DATA  = 2'b10,
                     STOP  = 2'b11;

    reg [1:0]          ps, ns;
    reg [WORD_LEN-1:0] output_reg;
    reg [3:0]          count;
    reg [3:0]          bit_idx;

    always @(posedge uart_clk or negedge sys_rst_I) begin
        if (sys_rst_I==0) ps <= IDLE;
        else              ps <= ns;
    end

    always @(*) begin
        ns = ps;
        case (ps)
            IDLE  : ns = xmitH           ? START : IDLE;
            START : ns = (count == 4'd15)   ? DATA  : START;
            DATA  : ns = (count == 4'd15 && bit_idx == WORD_LEN-1) ? STOP : DATA;
            STOP  : ns = (count == 4'd15)   ? IDLE  : STOP;
            default: ns = IDLE;
        endcase
    end

    always @(posedge uart_clk or negedge sys_rst_I) begin
        if (sys_rst_I==0) begin
            uart_XMIT_dataH <= 1'b1;
            xmit_doneH      <= 1'b1;
            xmit_activeH    <= 1'b0;
            output_reg      <= {WORD_LEN{1'b0}};
            count           <= 4'd0;
            bit_idx         <= 4'd0;
        end else begin
            case (ps)

                IDLE: begin
                    if (xmitH) begin
                        output_reg      <= xmit_dataH;
                        xmit_activeH    <= 1'b1;
                        xmit_doneH      <= 1'b0;
                        uart_XMIT_dataH <= 1'b0;
                        count           <= 4'd0;
                        bit_idx         <= 4'd0;
                    end else begin
                        uart_XMIT_dataH <= 1'b1;
                        xmit_doneH      <= 1'b1;
                        xmit_activeH    <= 1'b0;
                        count           <= 4'd0;
                        bit_idx         <= 4'd0;
                    end
                end

                START: begin
                    uart_XMIT_dataH <= 1'b0;
                    count <= count + 1'b1;
                    if (count == 4'd15)
                        count <= 4'd0;
                end

                DATA: begin
                    uart_XMIT_dataH <= output_reg[bit_idx];
                    count <= count + 1'b1;
                    if (count == 4'd15) begin
                        count <= 4'd0;
                        if (bit_idx == WORD_LEN - 1)
                            bit_idx <= 4'd0;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end
                end

                STOP: begin
                    uart_XMIT_dataH <= 1'b1;
                    count <= count + 1'b1;
                    if (count == 4'd15) begin
                        count        <= 4'd0;
                        xmit_doneH   <= 1'b1;
                        xmit_activeH <= 1'b0;
                    end
                end

                default: uart_XMIT_dataH <= 1'b1;

            endcase
        end
    end

endmodule