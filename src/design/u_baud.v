module u_baud #(
    parameter integer XTAL_CLK = 10_000_000,
    parameter integer BAUD     = 9_600,
    parameter integer CLK_DIV  = XTAL_CLK / (BAUD * 16 * 2),
    parameter integer CW       = $clog2(CLK_DIV)   // counter width
)(
    input  wire sys_clk,
    input  wire sys_rst_I,   
    output reg  uart_clk     
);

    reg [CW-1:0] count;

    always @(posedge sys_clk or posedge sys_rst_I) begin
        if (sys_rst_I==0) begin
            count    <= {CW{1'b0}};
            uart_clk <= 1'b0;
        end else begin
            if (count == CLK_DIV - 1) begin
                count    <= {CW{1'b0}};
                uart_clk <= ~uart_clk;      
            end else begin
                count <= count + 1'b1;
            end
        end
    end

endmodule

