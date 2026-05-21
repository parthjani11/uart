module u_rec #(
    parameter integer WORD_LEN = 8
)(
    input  wire                  uart_clk,
    input  wire                  sys_rst_I,
    input  wire                  uart_RECdataH1,
    output reg  [WORD_LEN-1:0]   rec_DataH,
    output reg                   rec_readyH,
    output reg                   rec_busyH
);

    localparam [1:0] IDLE      = 2'b00,
                     START_CHK = 2'b01,
                     DATA      = 2'b10,
                     STOP      = 2'b11;

    reg [1:0]          ps, ns;
    reg [WORD_LEN-1:0] temp_data;
    reg [3:0]          counter;
    reg [3:0]          bit_idx;
    reg sync1,uart_RECdataH;

    always @(posedge uart_clk or negedge sys_rst_I) begin
        if (sys_rst_I==0) ps <= IDLE;
        else           ps <= ns;
    end

    always @(posedge uart_clk or negedge sys_rst_I) begin
        if (sys_rst_I==0) begin
            sync1<=1;
            uart_RECdataH<=1;
        end
        else  begin
            sync1<=uart_RECdataH1;
            uart_RECdataH<=sync1;
        end
    end

    always @(*) begin
        ns = ps;
        case (ps)
            IDLE:
                ns = (!uart_RECdataH) ? START_CHK : IDLE;

            START_CHK:
                if (counter == 4'd4)
                    ns = (!uart_RECdataH) ? DATA : IDLE;
                else
                    ns = START_CHK;

            DATA:
                ns = (counter == 4'd15 && bit_idx == WORD_LEN-1) ? STOP : DATA;

            STOP:
                ns = (counter == 4'd15) ? IDLE : STOP;

            default: ns = IDLE;
        endcase
    end

    always @(posedge uart_clk or negedge sys_rst_I) begin
        if (sys_rst_I==0) begin
            temp_data  <= {WORD_LEN{1'b0}};
            rec_DataH  <= {WORD_LEN{1'b0}};
            rec_readyH <= 1'b1;
            rec_busyH  <= 1'b0;
            counter    <= 4'd0;
            bit_idx    <= 4'd0;
        end else begin
            rec_readyH <= 1'b0;

            case (ps)

                IDLE: begin
                    rec_busyH <= 1'b0;
                    rec_readyH <= 1'b1;
                    counter   <= 4'd0;
                    bit_idx   <= 4'd0;
                    if (!uart_RECdataH)
                        rec_busyH <= 1'b1;
                end

                START_CHK: begin
                    counter <= counter + 1'b1;
                    if (counter == 4'd4) begin
                        counter <= 4'd0;
                        if (uart_RECdataH)begin
                            rec_busyH <= 1'b1;
                            rec_readyH <= 1'b0;end
                    end
                end

                DATA: begin
                    counter <= counter + 1'b1;
                    if (counter == 4'd15) begin
                        temp_data[bit_idx] <= uart_RECdataH;
                        counter <= 4'd0;
                        if (bit_idx == WORD_LEN - 1)
                            bit_idx <= 4'd0;
                        else
                            bit_idx <= bit_idx + 1'b1;
                    end
                end

                STOP: begin
                    counter <= counter + 1'b1;
                    if (counter == 4'd15) begin
                        counter   <= 4'd0;
                        rec_busyH <= 1'b0;
                        if (uart_RECdataH) begin
                            rec_DataH  <= temp_data;
                            rec_readyH <= 1'b1;
                            rec_busyH <= 1'b0;
                        end
                    end
                end

                default: counter <= 4'd0;

            endcase
        end
    end

endmodule