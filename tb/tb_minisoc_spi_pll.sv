// ==============================================================================
// Testbench: tb_minisoc_spi_pll
// Description: Self-checking Directed Testbench for MiniSoC SPI Front-End
//              (minisoc_spi) and PLL Mock Model (minisoc_pll_mock) - Semana 5:
//              1. Reset state verification (all R/W regs = 0, VERSION = 0x00010000,
//                 PLL_LOCKED = 0, sys_clk gated).
//              2. Full SPI Write & 2-Transaction Read (with NOP 0x3F return) of
//                 all R/W registers: KEY0..KEY3, IV0..IV3, COUNTER_HI/LO,
//                 NUM_BLOCKS, AES_CONTROL (incl. START write-one-pulse check),
//                 and SYSTEM_CONTROL.
//              3. Read-Only register write protection: AES_STATUS, VERSION,
//                 SYSTEM_STATUS, plus NOP/unmapped address write immunity.
//              4. Programming Model Steps 8 & 9 (Block Guide Sec. 9):
//                 Enable PLL via SPI and poll SYSTEM_STATUS until PLL_LOCKED=1
//                 across all four divisors (/1, /2, /4, /8), verifying:
//                 - sys_clk strictly blocked while disabled or unlocking
//                 - pseudo-random lock acquisition delay in clk cycles
//                 - exact output clock periods (0.5ns, 1.0ns, 2.0ns, 4.0ns)
//                 - clean unlock and clock gating upon disable.
// ==============================================================================

module tb_minisoc_spi_pll;

    // --------------------------------------------------------------------------
    // Register Address Map (Block Guide Sec. 6)
    // --------------------------------------------------------------------------
    localparam logic [5:0] ADDR_KEY0           = 6'h00;
    localparam logic [5:0] ADDR_KEY1           = 6'h01;
    localparam logic [5:0] ADDR_KEY2           = 6'h02;
    localparam logic [5:0] ADDR_KEY3           = 6'h03;
    localparam logic [5:0] ADDR_IV0            = 6'h04;
    localparam logic [5:0] ADDR_IV1            = 6'h05;
    localparam logic [5:0] ADDR_IV2            = 6'h06;
    localparam logic [5:0] ADDR_IV3            = 6'h07;
    localparam logic [5:0] ADDR_COUNTER_HI     = 6'h08;
    localparam logic [5:0] ADDR_COUNTER_LO     = 6'h09;
    localparam logic [5:0] ADDR_NUM_BLOCKS     = 6'h0A;
    localparam logic [5:0] ADDR_AES_CONTROL    = 6'h0B;
    localparam logic [5:0] ADDR_AES_STATUS     = 6'h0C;
    localparam logic [5:0] ADDR_VERSION        = 6'h0D;
    localparam logic [5:0] ADDR_SYSTEM_CONTROL = 6'h0E;
    localparam logic [5:0] ADDR_SYSTEM_STATUS  = 6'h0F;
    localparam logic [5:0] ADDR_UNMAPPED       = 6'h2A;
    localparam logic [5:0] ADDR_NOP            = 6'h3F;

    localparam logic [31:0] EXP_VERSION_ID = 32'h0001_0000;

    // SPI SCLK = 25 MHz -> Period = 40 ns -> Half-period = 20 ns
    localparam realtime SPI_HALF_PERIOD = 20.0;

    // --------------------------------------------------------------------------
    // Reference Clock (2.000 GHz -> T = 0.5 ns -> Half-period = 0.25 ns) & Reset
    // --------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 1'b0;
        forever #0.25 clk = ~clk;
    end

    // --------------------------------------------------------------------------
    // DUT Interconnect Signals
    // --------------------------------------------------------------------------
    logic         spi_sclk;
    logic         spi_cs_n;
    logic         spi_mosi;
    logic         spi_miso;

    logic [127:0] cfg_key;
    logic [127:0] cfg_iv;
    logic [63:0]  cfg_counter;
    logic [31:0]  cfg_num_blocks;
    logic [2:0]   cfg_mode;
    logic         cfg_decrypt;
    logic         aes_start;

    logic         aes_busy;
    logic         aes_done;
    logic         aes_error;
    logic [8:0]   aes_blocks_done;

    logic         mem_sel_aes;
    logic         pll_enable;
    logic [1:0]   pll_div_sel;
    logic         pll_locked;
    logic         sys_clk;

    // --------------------------------------------------------------------------
    // DUT Instantiations: minisoc_spi + minisoc_pll_mock
    // --------------------------------------------------------------------------
    minisoc_spi #(
        .VERSION_ID (EXP_VERSION_ID)
    ) u_dut_spi (
        .clk_i             (clk),
        .rst_ni            (rst_n),
        .spi_sclk_i        (spi_sclk),
        .spi_cs_ni         (spi_cs_n),
        .spi_mosi_i        (spi_mosi),
        .spi_miso_o        (spi_miso),
        .cfg_key_o         (cfg_key),
        .cfg_iv_o          (cfg_iv),
        .cfg_counter_o     (cfg_counter),
        .cfg_num_blocks_o  (cfg_num_blocks),
        .cfg_mode_o        (cfg_mode),
        .cfg_decrypt_o     (cfg_decrypt),
        .aes_start_o       (aes_start),
        .aes_busy_i        (aes_busy),
        .aes_done_i        (aes_done),
        .aes_error_i       (aes_error),
        .aes_blocks_done_i (aes_blocks_done),
        .mem_sel_aes_o     (mem_sel_aes),
        .pll_enable_o      (pll_enable),
        .pll_div_sel_o     (pll_div_sel),
        .pll_locked_i      (pll_locked)
    );

    minisoc_pll_mock u_dut_pll (
        .clk_i         (clk),
        .rst_ni        (rst_n),
        .pll_en_i      (pll_enable),
        .pll_div_sel_i (pll_div_sel),
        .sys_clk_o     (sys_clk),
        .locked_o      (pll_locked)
    );

    // --------------------------------------------------------------------------
    // Background Monitors (Cycle Counter, START Pulse Counter, Glitch Checker)
    // --------------------------------------------------------------------------
    logic [63:0] clk_cycle_cnt;
    logic [31:0] aes_start_pulse_cnt;
    logic        pll_en_d_q;
    logic        pll_locked_d_q;
    logic [63:0] pll_en_rise_cyc;
    logic [63:0] pll_lock_rise_cyc;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cycle_cnt       <= 64'd0;
            aes_start_pulse_cnt <= 32'd0;
            pll_en_d_q          <= 1'b0;
            pll_locked_d_q      <= 1'b0;
            pll_en_rise_cyc     <= 64'd0;
            pll_lock_rise_cyc   <= 64'd0;
        end else begin
            clk_cycle_cnt  <= clk_cycle_cnt + 64'd1;
            pll_en_d_q     <= pll_enable;
            pll_locked_d_q <= pll_locked;

            if (aes_start) begin
                aes_start_pulse_cnt <= aes_start_pulse_cnt + 32'd1;
            end
            if (pll_enable && !pll_en_d_q) begin
                pll_en_rise_cyc <= clk_cycle_cnt;
            end
            if (pll_locked && !pll_locked_d_q) begin
                pll_lock_rise_cyc <= clk_cycle_cnt;
            end
        end
    end

    logic [31:0] sys_clk_edge_cnt   = 32'd0;
    logic [31:0] sys_clk_glitch_cnt = 32'd0;

    always @(posedge sys_clk) begin
        sys_clk_edge_cnt <= sys_clk_edge_cnt + 32'd1;
        if (!pll_locked) begin
            $display("  [FAIL] REQ-PLL-01 violation: sys_clk toggled while pll_locked=0 at t=%0t",
                     $realtime);
            sys_clk_glitch_cnt <= sys_clk_glitch_cnt + 32'd1;
        end
    end

    // --------------------------------------------------------------------------
    // Verification Counters & Helper Tasks
    // --------------------------------------------------------------------------
    int err_cnt;
    int pass_cnt;

    task automatic check_eq32(
        input string       label,
        input logic [31:0] got,
        input logic [31:0] exp
    );
        if (got !== exp) begin
            $display("  [FAIL] %s: got 32'h%08h, exp 32'h%08h", label, got, exp);
            err_cnt++;
        end else begin
            $display("  [PASS] %s: 32'h%08h", label, got);
            pass_cnt++;
        end
    endtask

    // SPI Mode 0, MSB-first, 40-bit full-duplex transfer (25 MHz)
    task automatic spi_transfer_40b(
        input  logic [39:0] tx_frame,
        output logic [39:0] rx_frame
    );
        rx_frame = 40'd0;
        spi_sclk = 1'b0;
        spi_mosi = tx_frame[39];
        spi_cs_n = 1'b0;

        for (int i = 39; i >= 0; i--) begin
            spi_mosi = tx_frame[i];
            #(SPI_HALF_PERIOD);
            spi_sclk    = 1'b1;      // Rising edge: slave samples MOSI, master samples MISO
            rx_frame[i] = spi_miso;
            #(SPI_HALF_PERIOD);
            spi_sclk    = 1'b0;      // Falling edge: slave updates MISO
        end

        #(SPI_HALF_PERIOD);
        spi_cs_n = 1'b1;
        spi_mosi = 1'b0;
        #(SPI_HALF_PERIOD);
    endtask

    // Single-transaction SPI Write: {RWb=0, ADDR[5:0], RSV=0, DATA[31:0]}
    task automatic spi_write(
        input logic [5:0]  addr,
        input logic [31:0] wdata
    );
        logic [39:0] unused_rx;
        spi_transfer_40b({1'b0, addr, 1'b0, wdata}, unused_rx);
    endtask

    // Two-transaction SPI Read:
    //   1st tx: {RWb=1, ADDR[5:0], RSV=0, 32'h0}
    //   2nd tx: {RWb=0, NOP(0x3F), RSV=0, 32'h0} -> shifts out {8'h00, rdata[31:0]}
    task automatic spi_read(
        input  logic [5:0]  addr,
        output logic [31:0] rdata
    );
        logic [39:0] rx_phase1;
        logic [39:0] rx_phase2;
        spi_transfer_40b({1'b1, addr, 1'b0, 32'h0000_0000}, rx_phase1);
        spi_transfer_40b({1'b0, ADDR_NOP, 1'b0, 32'h0000_0000}, rx_phase2);
        if (rx_phase2[39:32] !== 8'h00) begin
            $display("  [FAIL] SPI Read addr 0x%02h non-zero MISO header: 8'h%02h",
                     addr, rx_phase2[39:32]);
            err_cnt++;
        end
        rdata = rx_phase2[31:0];
    endtask

    // Measure sys_clk period averaged over 4 cycles with timeout protection
    task automatic measure_sys_clk_period(
        output realtime measured_period_ns,
        output logic    timed_out
    );
        realtime t_start;
        realtime t_end;
        timed_out          = 1'b0;
        measured_period_ns = 0.0;

        fork
            begin : p_measure
                repeat (3) @(posedge sys_clk);
                t_start = $realtime;
                repeat (4) @(posedge sys_clk);
                t_end = $realtime;
                measured_period_ns = (t_end - t_start) / 4.0;
            end
            begin : p_timeout
                #200.0;
                timed_out = 1'b1;
            end
        join_any
        disable fork;
    endtask

    // --------------------------------------------------------------------------
    // Main Test Sequence
    // --------------------------------------------------------------------------
    logic [31:0] rdata;
    logic [31:0] start_cnt_before;
    logic [31:0] sys_edges_before;
    logic [1:0]  div_code;
    logic [63:0] lock_latencies [0:3];
    realtime     exp_periods    [0:3];
    realtime     meas_period;
    logic        meas_timeout;
    int          poll_iter;

    initial begin
        err_cnt         = 0;
        pass_cnt        = 0;
        rst_n           = 1'b0;
        spi_sclk        = 1'b0;
        spi_cs_n        = 1'b1;
        spi_mosi        = 1'b0;
        aes_busy        = 1'b0;
        aes_done        = 1'b0;
        aes_error       = 1'b0;
        aes_blocks_done = 9'd0;

        exp_periods[0]  = 0.500; // /1 -> 2.000 GHz
        exp_periods[1]  = 1.000; // /2 -> 1.000 GHz
        exp_periods[2]  = 2.000; // /4 -> 500 MHz
        exp_periods[3]  = 4.000; // /8 -> 250 MHz

        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (10) @(posedge clk);

        $display("========================================================================");
        $display("   MiniSoC AES - Semana 5 Testbench (SPI Front-End & PLL Mock Model)    ");
        $display("========================================================================");

        // ======================================================================
        // TEST 1: Reset State & PLL Disabled Check
        // ======================================================================
        $display("\n[TEST 1] Reset State & PLL Disabled Verification:");

        spi_read(ADDR_VERSION, rdata);
        check_eq32("VERSION (0x0D) reset", rdata, EXP_VERSION_ID);

        spi_read(ADDR_SYSTEM_STATUS, rdata);
        check_eq32("SYSTEM_STATUS (0x0F) reset (PLL_LOCKED=0)", rdata, 32'h0000_0000);

        spi_read(ADDR_SYSTEM_CONTROL, rdata);
        check_eq32("SYSTEM_CONTROL (0x0E) reset", rdata, 32'h0000_0000);

        spi_read(ADDR_AES_CONTROL, rdata);
        check_eq32("AES_CONTROL (0x0B) reset", rdata, 32'h0000_0000);

        sys_edges_before = sys_clk_edge_cnt;
        repeat (50) @(posedge clk);
        if (sys_clk_edge_cnt !== sys_edges_before) begin
            $display("  [FAIL] sys_clk toggled while PLL disabled after reset!");
            err_cnt++;
        end else begin
            $display("  [PASS] sys_clk strictly blocked (0 edges) while PLL disabled");
            pass_cnt++;
        end

        // ======================================================================
        // TEST 2: Write & Readback of All R/W Registers via SPI
        // ======================================================================
        $display("\n[TEST 2] R/W Registers Write & Readback via SPI:");

        // KEY0..KEY3
        spi_write(ADDR_KEY0, 32'h0001_0203);
        spi_write(ADDR_KEY1, 32'h0405_0607);
        spi_write(ADDR_KEY2, 32'h0809_0A0B);
        spi_write(ADDR_KEY3, 32'h0C0D_0E0F);

        spi_read(ADDR_KEY0, rdata); check_eq32("KEY0 (0x00)", rdata, 32'h0001_0203);
        spi_read(ADDR_KEY1, rdata); check_eq32("KEY1 (0x01)", rdata, 32'h0405_0607);
        spi_read(ADDR_KEY2, rdata); check_eq32("KEY2 (0x02)", rdata, 32'h0809_0A0B);
        spi_read(ADDR_KEY3, rdata); check_eq32("KEY3 (0x03)", rdata, 32'h0C0D_0E0F);

        if (cfg_key !== 128'h00010203_04050607_08090A0B_0C0D0E0F) begin
            $display("  [FAIL] cfg_key_o mismatch: got %032h", cfg_key);
            err_cnt++;
        end else begin
            $display("  [PASS] cfg_key_o bus = %032h", cfg_key);
            pass_cnt++;
        end

        // IV0..IV3
        spi_write(ADDR_IV0, 32'h1011_1213);
        spi_write(ADDR_IV1, 32'h1415_1617);
        spi_write(ADDR_IV2, 32'h1819_1A1B);
        spi_write(ADDR_IV3, 32'h1C1D_1E1F);

        spi_read(ADDR_IV0, rdata); check_eq32("IV0  (0x04)", rdata, 32'h1011_1213);
        spi_read(ADDR_IV1, rdata); check_eq32("IV1  (0x05)", rdata, 32'h1415_1617);
        spi_read(ADDR_IV2, rdata); check_eq32("IV2  (0x06)", rdata, 32'h1819_1A1B);
        spi_read(ADDR_IV3, rdata); check_eq32("IV3  (0x07)", rdata, 32'h1C1D_1E1F);

        if (cfg_iv !== 128'h10111213_14151617_18191A1B_1C1D1E1F) begin
            $display("  [FAIL] cfg_iv_o mismatch: got %032h", cfg_iv);
            err_cnt++;
        end else begin
            $display("  [PASS] cfg_iv_o bus  = %032h", cfg_iv);
            pass_cnt++;
        end

        // COUNTER_HI / COUNTER_LO
        spi_write(ADDR_COUNTER_HI, 32'hDEAD_BEEF);
        spi_write(ADDR_COUNTER_LO, 32'hCAFE_BABE);

        spi_read(ADDR_COUNTER_HI, rdata); check_eq32("COUNTER_HI (0x08)", rdata, 32'hDEAD_BEEF);
        spi_read(ADDR_COUNTER_LO, rdata); check_eq32("COUNTER_LO (0x09)", rdata, 32'hCAFE_BABE);

        if (cfg_counter !== 64'hDEAD_BEEF_CAFE_BABE) begin
            $display("  [FAIL] cfg_counter_o mismatch: got %016h", cfg_counter);
            err_cnt++;
        end else begin
            $display("  [PASS] cfg_counter_o = %016h", cfg_counter);
            pass_cnt++;
        end

        // NUM_BLOCKS
        spi_write(ADDR_NUM_BLOCKS, 32'h0000_0100);
        spi_read(ADDR_NUM_BLOCKS, rdata);
        check_eq32("NUM_BLOCKS (0x0A)", rdata, 32'h0000_0100);

        if (cfg_num_blocks !== 32'd256) begin
            $display("  [FAIL] cfg_num_blocks_o mismatch: got %0d", cfg_num_blocks);
            err_cnt++;
        end else begin
            $display("  [PASS] cfg_num_blocks_o = %0d", cfg_num_blocks);
            pass_cnt++;
        end

        // AES_CONTROL (without START, upper reserved bits set to verify masking)
        start_cnt_before = aes_start_pulse_cnt;
        spi_write(ADDR_AES_CONTROL, {27'h7FF_FFFF, 3'b101, 1'b1, 1'b0});
        spi_read(ADDR_AES_CONTROL, rdata);
        check_eq32("AES_CONTROL (0x0B) MODE=101, DECRYPT=1, START=0", rdata, 32'h0000_0016);

        if ((aes_start_pulse_cnt !== start_cnt_before) || (cfg_mode !== 3'b101) || (cfg_decrypt !== 1'b1)) begin
            $display("  [FAIL] AES_CONTROL outputs mismatch: mode=%03b dec=%0b start_pulses=%0d",
                     cfg_mode, cfg_decrypt, aes_start_pulse_cnt - start_cnt_before);
            err_cnt++;
        end else begin
            $display("  [PASS] AES_CONTROL outputs ok & 0 START pulses when START=0");
            pass_cnt++;
        end

        // AES_CONTROL (with START=1 -> write-one-pulse verification)
        start_cnt_before = aes_start_pulse_cnt;
        spi_write(ADDR_AES_CONTROL, {27'd0, 3'b010, 1'b0, 1'b1});
        if ((aes_start_pulse_cnt - start_cnt_before) !== 32'd1) begin
            $display("  [FAIL] AES_CONTROL.START W1P: expected 1 clk pulse, got %0d",
                     aes_start_pulse_cnt - start_cnt_before);
            err_cnt++;
        end else begin
            $display("  [PASS] AES_CONTROL.START generated exactly 1 clk cycle pulse (W1P)");
            pass_cnt++;
        end

        spi_read(ADDR_AES_CONTROL, rdata);
        check_eq32("AES_CONTROL (0x0B) readback after START=1 (self-cleared)", rdata, 32'h0000_0008);

        // SYSTEM_CONTROL (MEM_SEL_AES=1, PLL_ENABLE=0, PLL_DIV_SEL=11 + reserved mask)
        spi_write(ADDR_SYSTEM_CONTROL, {28'hFFF_FFFF, 2'b11, 1'b0, 1'b1});
        spi_read(ADDR_SYSTEM_CONTROL, rdata);
        check_eq32("SYSTEM_CONTROL (0x0E) MEM_SEL=1, PLL_EN=0, DIV=11", rdata, 32'h0000_000D);

        if ((mem_sel_aes !== 1'b1) || (pll_enable !== 1'b0) || (pll_div_sel !== 2'b11)) begin
            $display("  [FAIL] SYSTEM_CONTROL pins mismatch: mem_sel=%0b pll_en=%0b div=%02b",
                     mem_sel_aes, pll_enable, pll_div_sel);
            err_cnt++;
        end else begin
            $display("  [PASS] SYSTEM_CONTROL pins verified (mem_sel=1, pll_en=0, div=11)");
            pass_cnt++;
        end

        // Return MEM_SEL_AES=0, PLL_ENABLE=0, PLL_DIV_SEL=00
        spi_write(ADDR_SYSTEM_CONTROL, 32'h0000_0000);
        spi_read(ADDR_SYSTEM_CONTROL, rdata);
        check_eq32("SYSTEM_CONTROL (0x0E) restored to 0", rdata, 32'h0000_0000);

        // ======================================================================
        // TEST 3: Read-Only Registers Write Protection & NOP Immunity
        // ======================================================================
        $display("\n[TEST 3] Read-Only Registers Write Protection & NOP Immunity:");

        // Drive known live AES status values: BUSY=1, DONE=1, ERROR=0, BLOCKS_DONE=137 (9'h089)
        // Expected: {20'd0, 9'd137, 1'b0, 1'b1, 1'b1} = 32'h0000_044B
        aes_busy        = 1'b1;
        aes_done        = 1'b1;
        aes_error       = 1'b0;
        aes_blocks_done = 9'd137;
        repeat (4) @(posedge clk);

        spi_read(ADDR_AES_STATUS, rdata);
        check_eq32("AES_STATUS (0x0C) live read", rdata, 32'h0000_044B);

        // Attempt illegal writes to all R-only registers
        spi_write(ADDR_AES_STATUS,    32'hFFFF_FFFF);
        spi_write(ADDR_VERSION,       32'hA5A5_5A5A);
        spi_write(ADDR_SYSTEM_STATUS, 32'hFFFF_FFFF);
        spi_write(ADDR_NOP,           32'hDEAD_C0DE);
        spi_write(ADDR_UNMAPPED,      32'h1234_5678);

        spi_read(ADDR_AES_STATUS, rdata);
        check_eq32("AES_STATUS (0x0C) unchanged after write", rdata, 32'h0000_044B);

        spi_read(ADDR_VERSION, rdata);
        check_eq32("VERSION (0x0D) unchanged after write", rdata, EXP_VERSION_ID);

        spi_read(ADDR_SYSTEM_STATUS, rdata);
        check_eq32("SYSTEM_STATUS (0x0F) unchanged after write", rdata, 32'h0000_0000);

        // Confirm KEY0 was not corrupted by NOP/unmapped writes
        spi_read(ADDR_KEY0, rdata);
        check_eq32("KEY0 (0x00) intact after NOP/unmapped writes", rdata, 32'h0001_0203);

        // ======================================================================
        // TEST 4: PLL Enable & Lock Polling (Steps 8 & 9) Across All 4 Dividers
        // ======================================================================
        $display("\n[TEST 4] PLL Enable & Lock Polling (Sec. 9 Steps 8-9) - All 4 Dividers:");

        for (int d = 0; d < 4; d++) begin
            div_code = 2'(d);

            $display("\n  --- Divisor %0d (PLL_DIV_SEL = 2'b%02b -> /%0d, T_exp = %0.3f ns) ---",
                     d, div_code, (1 << d), exp_periods[d]);

            // Ensure PLL is disabled first
            spi_write(ADDR_SYSTEM_CONTROL, {28'd0, div_code, 1'b0, 1'b0});
            spi_read(ADDR_SYSTEM_STATUS, rdata);
            check_eq32("SYSTEM_STATUS before enable (PLL_LOCKED=0)", rdata, 32'h0000_0000);

            // Confirm sys_clk is completely blocked while disabled
            sys_edges_before = sys_clk_edge_cnt;
            repeat (40) @(posedge clk);
            if (sys_clk_edge_cnt !== sys_edges_before) begin
                $display("  [FAIL] sys_clk toggled while PLL disabled (div=2'b%02b)!", div_code);
                err_cnt++;
            end else begin
                $display("  [PASS] sys_clk blocked while disabled");
                pass_cnt++;
            end

            // Step 8: Program PLL_DIV_SEL and set PLL_ENABLE = 1 via SPI
            spi_write(ADDR_SYSTEM_CONTROL, {28'd0, div_code, 1'b1, 1'b0});

            // Step 9: Poll SYSTEM_STATUS via SPI until PLL_LOCKED == 1
            poll_iter = 0;
            rdata     = 32'h0;
            while ((rdata[0] !== 1'b1) && (poll_iter < 20)) begin
                spi_read(ADDR_SYSTEM_STATUS, rdata);
                poll_iter++;
            end

            if (rdata !== 32'h0000_0001) begin
                $display("  [FAIL] PLL did not lock for div=2'b%02b (SYSTEM_STATUS=32'h%08h)",
                         div_code, rdata);
                err_cnt++;
            end else begin
                lock_latencies[d] = pll_lock_rise_cyc - pll_en_rise_cyc;
                $display("  [PASS] PLL_LOCKED=1 via SPI poll (%0d read(s)), lock latency = %0d clk cycles",
                         poll_iter, lock_latencies[d]);
                pass_cnt++;
            end

            // Measure actual sys_clk period and verify against specification
            measure_sys_clk_period(meas_period, meas_timeout);
            if (meas_timeout) begin
                $display("  [FAIL] Timeout measuring sys_clk for div=2'b%02b!", div_code);
                err_cnt++;
            end else if ((meas_period < (exp_periods[d] - 0.002)) ||
                         (meas_period > (exp_periods[d] + 0.002))) begin
                $display("  [FAIL] sys_clk period mismatch for div=2'b%02b: got %0.3f ns, exp %0.3f ns",
                         div_code, meas_period, exp_periods[d]);
                err_cnt++;
            end else begin
                $display("  [PASS] sys_clk period verified: %0.3f ns (exp %0.3f ns)",
                         meas_period, exp_periods[d]);
                pass_cnt++;
            end
        end

        // Verify pseudo-randomness across lock acquisitions (not all identical)
        if ((lock_latencies[0] == lock_latencies[1]) &&
            (lock_latencies[1] == lock_latencies[2]) &&
            (lock_latencies[2] == lock_latencies[3])) begin
            $display("\n  [FAIL] PLL lock latency was constant (%0d cycles) across all 4 enables!",
                     lock_latencies[0]);
            err_cnt++;
        end else begin
            $display("\n  [PASS] Pseudo-random lock latencies observed: [%0d, %0d, %0d, %0d] clk cycles",
                     lock_latencies[0], lock_latencies[1], lock_latencies[2], lock_latencies[3]);
            pass_cnt++;
        end

        // Dynamic divisor switch while enabled (/8 -> /2): must re-lock cleanly
        $display("\n  --- Dynamic Divisor Switch (/8 -> /2 while PLL_ENABLE=1) ---");
        spi_write(ADDR_SYSTEM_CONTROL, {28'd0, 2'b01, 1'b1, 1'b0});
        poll_iter = 0;
        rdata     = 32'h0;
        while ((rdata[0] !== 1'b1) && (poll_iter < 20)) begin
            spi_read(ADDR_SYSTEM_STATUS, rdata);
            poll_iter++;
        end
        if (rdata !== 32'h0000_0001) begin
            $display("  [FAIL] PLL did not re-lock after dynamic switch to /2!");
            err_cnt++;
        end else begin
            measure_sys_clk_period(meas_period, meas_timeout);
            if (meas_timeout || (meas_period < 0.998) || (meas_period > 1.002)) begin
                $display("  [FAIL] Dynamic switch /2 period mismatch: got %0.3f ns, exp 1.000 ns",
                         meas_period);
                err_cnt++;
            end else begin
                $display("  [PASS] Dynamic switch /8 -> /2 re-locked cleanly (T = %0.3f ns)",
                         meas_period);
                pass_cnt++;
            end
        end

        // Disable PLL at the end and verify clean unlock & clock gating
        spi_write(ADDR_SYSTEM_CONTROL, 32'h0000_0000);
        spi_read(ADDR_SYSTEM_STATUS, rdata);
        check_eq32("SYSTEM_STATUS after final disable (PLL_LOCKED=0)", rdata, 32'h0000_0000);

        sys_edges_before = sys_clk_edge_cnt;
        repeat (40) @(posedge clk);
        if (sys_clk_edge_cnt !== sys_edges_before) begin
            $display("  [FAIL] sys_clk did not stop after final PLL disable!");
            err_cnt++;
        end else begin
            $display("  [PASS] sys_clk cleanly stopped after final PLL disable");
            pass_cnt++;
        end

        // Check global REQ-PLL-01 monitor
        if (sys_clk_glitch_cnt !== 32'd0) begin
            $display("  [FAIL] Total REQ-PLL-01 sys_clk glitch violations: %0d", sys_clk_glitch_cnt);
            err_cnt++;
        end else begin
            $display("  [PASS] REQ-PLL-01 monitor: 0 unauthorized sys_clk edges in entire simulation");
            pass_cnt++;
        end

        // ======================================================================
        // Final Summary
        // ======================================================================
        $display("\n========================================================================");
        if (err_cnt == 0) begin
            $display("   OVERALL RESULT: PASS (0 errors, %0d checks passed)", pass_cnt);
            $display("   - All R/W registers written and read back via SPI Mode 0");
            $display("   - All R-only registers unaffected by SPI writes");
            $display("   - PLL locked and frequency-verified on all 4 divisors (/1,/2,/4,/8)");
        end else begin
            $display("   OVERALL RESULT: FAIL (%0d errors, %0d checks passed)", err_cnt, pass_cnt);
        end
        $display("========================================================================");

        repeat (10) @(posedge clk);
        $finish;
    end

    initial begin
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_minisoc_spi_pll);
    end

endmodule
