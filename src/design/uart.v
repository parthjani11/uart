module uart #(
    parameter integer XTAL_CLK = 50_000_000,
    parameter integer BAUD     = 9_600,
    parameter integer WORD_LEN = 8
)(
    input  wire                  sys_clk,
    input  wire                  sys_rst_I,

    input  wire                  xmitH,
    input  wire [WORD_LEN-1:0]   xmit_dataH,
    output wire                  uart_XMIT_dataH,
    output wire                  xmit_doneH,
    output wire                  xmit_activeH,

    input  wire                  uart_RECdataH,
    output wire [WORD_LEN-1:0]   rec_DataH,
    output wire                  rec_readyH,
    output wire                  rec_busyH
);

    wire uart_clk;

    u_baud #(
        .XTAL_CLK (XTAL_CLK),
        .BAUD     (BAUD)
    ) u_baud_inst (
        .sys_clk  (sys_clk),
        .sys_rst_I(sys_rst_I),
        .uart_clk (uart_clk)
    );

    u_xmit #(
        .WORD_LEN (WORD_LEN)
    ) u_xmit_inst (
        .uart_clk        (uart_clk),
        .sys_rst_I       (sys_rst_I),
        .xmitH           (xmitH),
        .xmit_dataH      (xmit_dataH),
        .uart_XMIT_dataH (uart_XMIT_dataH),
        .xmit_doneH      (xmit_doneH),
        .xmit_activeH    (xmit_activeH)
    );

    u_rec #(
        .WORD_LEN (WORD_LEN)
    ) u_rec_inst (
        .uart_clk      (uart_clk),
        .sys_rst_I     (sys_rst_I),
        .uart_RECdataH1 (uart_RECdataH),
        .rec_DataH     (rec_DataH),
        .rec_readyH    (rec_readyH),
        .rec_busyH     (rec_busyH)
    );

endmodule
