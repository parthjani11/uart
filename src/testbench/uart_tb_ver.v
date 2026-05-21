`timescale 1ns / 1ps

module uart_tb_ver;
// ==========================================
// Testbench Signals Declarations
// ==========================================
parameter BAUD_RATE  = 192000;
parameter DATA_WIDTH = 8;
parameter CLK_FREQ   = 50000000;

// Outputs from the UART module (Wires in TB)
wire                  tb_uart_XMIT_dataH;
wire                  tb_xmit_doneH;
wire                  tb_xmit_active;
wire [DATA_WIDTH-1:0] tb_rec_dataH;
wire                  tb_rec_readyH;
wire                  tb_rec_busy;

// FIX #1,2: wire -> reg (these are assigned inside tasks, must be reg)
reg  [3:0]            tb_cnt_tx, tb_cnt_rx;
reg  [1:0]            tb_cnt_tx_state, tb_cnt_rx_state;

// Inputs to the UART module (Regs in TB to drive stimulus)
reg                   tb_xmitH;
reg  [DATA_WIDTH-1:0] tb_xmit_dataH;
reg  [DATA_WIDTH-1:0] tb_xmit_dataH_ref;
// FIX #3: wire -> reg (assigned procedurally inside task)
reg  [DATA_WIDTH-1:0] tb_rec_dataH_ref;
reg                   tb_sys_clk;
wire                   tb_uart_clk;
// FIX #4: unified to tb_sys_rst_l everywhere (was tb_sys_rst_1 in declaration,
//         but module port used tb_sys_rst_l -> one was always undeclared)
reg                   tb_sys_rst_l;
reg                   tb_uart_REC_dataH;
reg [$clog2(DATA_WIDTH)-1:0] tb_data_idx_tx, tb_data_idx_rx;
integer                   success_cnt, fail_cnt;
integer i,j,k=0;
// ==========================================
// Module Instantiation
// ==========================================
uart_spt #(
    .baud(BAUD_RATE),
    .dw(DATA_WIDTH),
    .clk_freq(CLK_FREQ)
) uut (
    // Outputs
    .uart_XMIT_dataH (tb_uart_XMIT_dataH),
    .xmit_doneH      (tb_xmit_doneH),
    .xmit_active     (tb_xmit_active),
    .rec_dataH       (tb_rec_dataH),
    .rec_readyH      (tb_rec_readyH),
    .rec_busy        (tb_rec_busy),
    // Inputs
    .xmitH           (tb_xmitH),
    .xmit_dataH      (tb_xmit_dataH),
    .sys_clk         (tb_sys_clk),
    .sys_rst_l       (tb_sys_rst_l),     // FIX #6: tb_sys_rst_l now properly declared
    .uart_REC_dataH  (tb_uart_REC_dataH)
);                                        // FIX #5: added closing );

u_baud_spt #(
    .baud(BAUD_RATE),
    .clk_freq(CLK_FREQ)
) clk_gen (
    .clk (tb_sys_clk),
    .rst (tb_sys_rst_l),                  // FIX #8: unified name
    .baud_clk(tb_uart_clk)
);                                        // FIX #7: added closing );

// ==========================================
// Clock Generation
// ==========================================
initial begin
    tb_sys_clk = 0;
    forever #10 tb_sys_clk = ~tb_sys_clk; // FIX #9: added #10 (50MHz = 20ns period, was 0-time infinite loop)
end                                        // FIX #10: added end

// ==========================================
// Task: Drive All Inputs
// Order: (Data, Xmit_Trigger, Reset_Val, Receive_Bit)
// ==========================================
task drive_all_inputs(
    input [DATA_WIDTH-1:0] data_in,
    input                  xmit_in,
    input                  rst_in,
    input                  rec_in
);                                         // FIX #11: added closing );
begin
    tb_xmit_dataH     = data_in;
    tb_xmitH          = xmit_in;
    tb_sys_rst_l      = rst_in;            // FIX #12: was tb_sys_rst_1
    tb_uart_REC_dataH = rec_in;
end
endtask

// ==========================================
// Task: Output Check
// ==========================================
task output_check(
    input [DATA_WIDTH-1:0] tb_xmit_dataH,
    input                  tb_xmitH,
    input                  tb_uart_clk,
    input                  tb_sys_rst_l,
    input                  tb_uart_REC_dataH
);                                          // FIX #13,14: removed trailing comma, added ;
begin                                       // FIX #15: added begin for task body
    if(tb_sys_rst_l == 0) begin
        // Reset state: XMIT line idle-high, done, not active; REC idle
        if(tb_uart_XMIT_dataH == 1 && tb_xmit_doneH == 1 && tb_xmit_active == 0 &&
           tb_rec_dataH == 0 && tb_rec_readyH == 1 && tb_rec_busy == 0)
            success_cnt = success_cnt + 1;
        else begin
            fail_cnt = fail_cnt + 1;
            $display("RESET CHECK FAIL: tb_xmit_dataH=%h, tb_xmitH=%b, tb_sys_rst_l=%b, tb_uart_REC_dataH=%b",
                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH); // FIX #20: xmitH->tb_xmitH
            $display("  Output: XMIT_data=%b, xmit_done=%b, xmit_active=%b, rec_data=%h, rec_readyH=%b, rec_busy=%b",
                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active, tb_rec_dataH, tb_rec_readyH, tb_rec_busy);
        end
    end
    else begin
        fork
            // -----------------------------------------------
            // TRANSMISSION CHECK
            // -----------------------------------------------
            begin
                // Idle state
                if(tb_cnt_tx_state == 0) begin
                    if(tb_xmitH == 0) begin
                        if(tb_uart_XMIT_dataH == 1 && tb_xmit_doneH == 1 && tb_xmit_active == 0)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX IDLE(xmit=0) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                     tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        //tb_cnt_tx_state = tb_cnt_tx_state + 1;
                    end
                    else begin
                        if(tb_xmit_doneH == 0 && tb_xmit_active == 1)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX IDLE(xmit=1) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        tb_xmit_dataH_ref = tb_xmit_dataH;
                        tb_cnt_tx_state = tb_cnt_tx_state + 1'b1;
                    end
                end

                // Start state
                else if(tb_cnt_tx_state == 1) begin
                    if(tb_cnt_tx <= 14) begin
                        if(tb_uart_XMIT_dataH == 0 && tb_xmit_doneH == 0 && tb_xmit_active == 1)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX START(cnt<15) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        tb_cnt_tx = tb_cnt_tx + 1;
                    end
                    else if(tb_cnt_tx == 15) begin
                        if(tb_uart_XMIT_dataH == 0 && tb_xmit_doneH == 0 && tb_xmit_active == 1)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX START(cnt=15) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        tb_cnt_tx = tb_cnt_tx + 1;
                        tb_cnt_tx_state = tb_cnt_tx_state + 1'b1;
                        $display("%d",tb_cnt_tx_state);
                    end
                end

                // Data state
                else if(tb_cnt_tx_state == 2) begin
                    if((tb_cnt_tx <= 14) && (tb_data_idx_tx == DATA_WIDTH-1)) begin
                        if(tb_uart_XMIT_dataH == tb_xmit_dataH_ref[tb_data_idx_tx] && tb_xmit_doneH == 0 && tb_xmit_active == 1)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX DATA(cnt<15) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        tb_cnt_tx = tb_cnt_tx + 1;
                    end
                    else if((tb_cnt_tx == 15) && (tb_data_idx_tx <= DATA_WIDTH-2)) begin
                        if(tb_uart_XMIT_dataH == tb_xmit_dataH_ref[tb_data_idx_tx] && tb_xmit_doneH == 0 && tb_xmit_active == 1)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX DATA(cnt=15,bit<last) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        tb_cnt_tx = tb_cnt_tx + 1;
                        tb_cnt_tx_state = tb_cnt_tx_state + 1;
                    end
                    else if((tb_cnt_tx == 15) && (tb_data_idx_tx == DATA_WIDTH-1)) begin
                        if(tb_uart_XMIT_dataH == tb_xmit_dataH_ref[tb_data_idx_tx] && tb_xmit_doneH == 0 && tb_xmit_active == 1)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX DATA(cnt=15,last bit) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        tb_cnt_tx       = tb_cnt_tx + 1;
                        tb_cnt_tx_state = tb_cnt_tx_state + 1;
                        tb_data_idx_tx  = tb_data_idx_tx + 1;
                    end
                end

                // Stop state
                else if(tb_cnt_tx_state == 3) begin
                    if(tb_cnt_tx <= 14) begin
                        if(tb_uart_XMIT_dataH == 1 && tb_xmit_doneH == 0 && tb_xmit_active == 1)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX STOP(cnt<15) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        tb_cnt_tx = tb_cnt_tx + 1;
                    end
                    else if(tb_cnt_tx == 15) begin
                        if(tb_uart_XMIT_dataH == 1 && tb_xmit_doneH == 0 && tb_xmit_active == 1)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("TX STOP(cnt=15) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: XMIT_data=%b, done=%b, active=%b",
                                      tb_uart_XMIT_dataH, tb_xmit_doneH, tb_xmit_active);
                        end
                        tb_cnt_tx       = tb_cnt_tx + 1;
                        tb_cnt_tx_state = tb_cnt_tx_state + 1;
                    end
                end
            end // end TX check

            // -----------------------------------------------
            // RECEIVER CHECK
            // FIX #22: removed illegal "reg [2:0] idle_rx" declared inside fork-join
            // -----------------------------------------------
            begin
                // Idle state
                if(tb_cnt_rx_state == 0) begin
                    if(tb_uart_REC_dataH == 0) begin
                        // FIX #16: = -> == in all receiver if conditions
                        if(tb_rec_readyH == 1'b1 && tb_rec_busy == 1'b0)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("RX IDLE(rec=0) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            // FIX #23: print relevant receiver signals (not transmitter)
                            $display("  Output: rec_readyH=%b, rec_busy=%b",
                                      tb_rec_readyH, tb_rec_busy);
                        end
                        tb_cnt_rx_state = tb_cnt_rx_state + 1; // FIX #21: was tb_cnt_tx_state
                    end
                    else if(tb_uart_REC_dataH == 1) begin
                        if(tb_rec_readyH == 1'b1 && tb_rec_busy == 1'b0) // FIX #16: = -> ==
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("RX IDLE(rec=1) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: rec_readyH=%b, rec_busy=%b",
                                      tb_rec_readyH, tb_rec_busy);
                        end
                    end
                end

                // Start check
                else if(tb_cnt_rx_state == 1) begin
                    if((tb_uart_REC_dataH == 0) && (tb_cnt_rx == 7)) begin
                        if(tb_rec_readyH == 1'b0 && tb_rec_busy == 1'b1) // FIX #16: = -> ==
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("RX START(centre) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: rec_readyH=%b, rec_busy=%b",
                                      tb_rec_readyH, tb_rec_busy);
                        end
                        tb_cnt_rx_state = tb_cnt_rx_state + 1; // FIX #21: was tb_cnt_tx_state
                        $display("Sampled data at centre for start bit = %b", tb_uart_REC_dataH);
                    end
                    else if((tb_uart_REC_dataH == 1) && (tb_cnt_rx == 7)) begin
                        fail_cnt = fail_cnt + 1;
                        $display("----- FAULTY: start bit at centre = %b (expected 0)", tb_uart_REC_dataH);
                    end
                    tb_cnt_rx = tb_cnt_rx + 1;
                end

                // Data check
                else if(tb_cnt_rx_state == 2) begin
                    // FIX #17: tb_uart_REC_dataH<=DATA_WIDTH-2 -> tb_data_idx_rx<=DATA_WIDTH-2
                    if((tb_cnt_rx == 15) && (tb_data_idx_rx <= DATA_WIDTH-2)) begin
                        if(tb_rec_dataH[tb_data_idx_rx] == tb_uart_REC_dataH) begin
                            if(tb_rec_readyH == 1'b0 && tb_rec_busy == 1'b1) // FIX #16: = -> ==
                                success_cnt = success_cnt + 1;
                            else begin
                                fail_cnt = fail_cnt + 1;
                                $display("RX DATA(bit[%0d] ready/busy) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                          tb_data_idx_rx, tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                                $display("  Output: rec_readyH=%b, rec_busy=%b",
                                          tb_rec_readyH, tb_rec_busy);
                            end
                            $display("Sampled data at centre for data bit[%0d] = %b", tb_data_idx_rx, tb_uart_REC_dataH);
                        end
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("----- FAULTY: data bit[%0d] at centre = %b", tb_data_idx_rx, tb_uart_REC_dataH);
                        end
                        tb_rec_dataH_ref[tb_data_idx_rx] = tb_uart_REC_dataH;
                        $display("_________________________________________________Data formation=%8b , index=%d",tb_rec_dataH_ref,tb_data_idx_rx);
                        tb_data_idx_rx = tb_data_idx_rx + 1;
                    end
                    // FIX #18: tb_uart_REC_dataH<=DATA_WIDTH-1 -> tb_data_idx_rx==DATA_WIDTH-1
                    else if((tb_cnt_rx == 15) && (tb_data_idx_rx == DATA_WIDTH-1)) begin
                        if(tb_rec_dataH[tb_data_idx_rx] == tb_uart_REC_dataH) begin
                            if(tb_rec_readyH == 1'b0 && tb_rec_busy == 1'b1) // FIX #16: = -> ==
                                success_cnt = success_cnt + 1;
                            else begin
                                fail_cnt = fail_cnt + 1;
                                $display("RX DATA(last bit ready/busy) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                          tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                                $display("  Output: rec_readyH=%b, rec_busy=%b",
                                          tb_rec_readyH, tb_rec_busy);
                            end
                            $display("Sampled data at centre for data bit[%0d] = %b", tb_data_idx_rx, tb_uart_REC_dataH);
                        end
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("----- FAULTY: data bit[%0d] at centre = %b", tb_data_idx_rx, tb_uart_REC_dataH);
                        end
                        tb_rec_dataH_ref[tb_data_idx_rx] = tb_uart_REC_dataH;
                        $display("_________________________________________________Data formation=%8b , index=%d",tb_rec_dataH_ref,tb_data_idx_rx);
                       /* // Full word comparison
                        if(tb_rec_dataH == tb_rec_dataH_ref)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            // FIX #19: tb_uart_REC_dataH_ref -> tb_rec_dataH_ref (was undeclared)
                            $display("----- FAULTY full word: received=%h, expected=%h", tb_rec_dataH, tb_rec_dataH_ref);
                        end*/
                        tb_data_idx_rx  = tb_data_idx_rx + 1;
                        tb_cnt_rx_state = tb_cnt_rx_state + 1;
                    end
                    tb_cnt_rx = tb_cnt_rx + 1;
                end

                // Stop check
                else if(tb_cnt_rx_state == 3) begin
                    if((tb_uart_REC_dataH == 1) && (tb_cnt_rx == 15)) begin
                        if(tb_rec_readyH == 1'b1 && tb_rec_busy == 1'b0) 
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            $display("RX STOP(centre) FAIL: data=%h, xmitH=%b, rst=%b, rec=%b",
                                      tb_xmit_dataH, tb_xmitH, tb_sys_rst_l, tb_uart_REC_dataH);
                            $display("  Output: rec_readyH=%b, rec_busy=%b",
                                      tb_rec_readyH, tb_rec_busy);
                        end
                        // Full word comparison
                        if(tb_rec_dataH == tb_rec_dataH_ref)
                            success_cnt = success_cnt + 1;
                        else begin
                            fail_cnt = fail_cnt + 1;
                            // FIX #19: tb_uart_REC_dataH_ref -> tb_rec_dataH_ref (was undeclared)
                            $display("----- FAULTY full word: received=%h, expected=%h", tb_rec_dataH, tb_rec_dataH_ref);
                        end

                        tb_cnt_rx_state = tb_cnt_rx_state + 1; // FIX #21: was tb_cnt_tx_state
                        $display("Sampled data at centre for stop bit = %b", tb_uart_REC_dataH);
                    end
                    else if((tb_uart_REC_dataH == 0) && (tb_cnt_rx == 15)) begin
                        fail_cnt = fail_cnt + 1;
                        $display("----- FAULTY: stop bit at centre = %b (expected 1)", tb_uart_REC_dataH);
                    end
                    tb_cnt_rx = tb_cnt_rx + 1;
                end
            end // end RX check

        join
    end
end   // FIX #15: end of task body begin
endtask

// ==========================================
// Initial Block: Stimulus Generation
// ==========================================

initial begin
	#80;
	tb_sys_rst_l=0;
	#80;
	tb_sys_rst_l=1;
	#80;
	repeat(150)
		begin
			@(posedge tb_sys_clk);
			//display("value of counter is: [%0d]",clk_gen.counter);
		end
    tb_cnt_tx       = 4'd0;
    tb_cnt_rx       = 4'd0;
    tb_cnt_tx_state = 2'd0;
    tb_cnt_rx_state = 2'd0;
    tb_data_idx_tx  = 0;
    tb_data_idx_rx  = 0;
    success_cnt     = 0;
    fail_cnt        = 0;


    //check for transmission 1
    drive_all_inputs(8'b10101010,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b10101010,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 2
    drive_all_inputs(8'b01010101,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b01010101,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 3
    drive_all_inputs(8'b11111111,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b11111111,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 4
    drive_all_inputs(8'b00000000,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b00000000,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 5
    drive_all_inputs(8'b00001111,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b00001111,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 6
    drive_all_inputs(8'b11110000,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b11110000,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 7
    drive_all_inputs(8'b00110011,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b00110011,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 8
    drive_all_inputs(8'b11001100,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b11001100,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 9
    drive_all_inputs(8'b10110111,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b10110111,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for transmission 10
    drive_all_inputs(8'b10111011,1,1,1);
    @(posedge tb_uart_clk);
    output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    drive_all_inputs(8'b10111011,0,1,1);
    for(i=1;i<=(32+(16*DATA_WIDTH)-1);i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for receiver 1 (10101010)

    //start bit
    drive_all_inputs(8'b00000000,0,1,0);
    for(i=0;i<=16;i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d0
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,0);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d1
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d2
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,0);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d3
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d4
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,0);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d5
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d6
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,0);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d7
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //stop bit
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //check for receiver 2 (01010101)

    //start bit
    drive_all_inputs(8'b00000000,0,1,0);
    for(i=0;i<=16;i=i+1)begin
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d0
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d1
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,0);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d2
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d3
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,0);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d4
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d5
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,0);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d6
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //d7
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,0);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    //stop bit
    for(i=0;i<=16;i=i+1)begin
        drive_all_inputs(8'b00000000,0,1,1);
        @(posedge tb_uart_clk);
        output_check(tb_xmit_dataH, tb_xmitH, tb_uart_clk, tb_sys_rst_l, tb_uart_REC_dataH);
    end

    $display("============================================");
    $display("         SIMULATION COMPLETE               ");
    $display("============================================");
    $display("  Total PASS  : %0d", success_cnt);
    $display("  Total FAIL  : %0d", fail_cnt);
    $display("============================================");

    $finish;

end

endmodule