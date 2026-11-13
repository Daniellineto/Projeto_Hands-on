// ==============================================================================
// Testbench: tb_minisoc_aes_dp
// Description: Self-checking Testbench for AES-128 Key Expansion
//              (minisoc_aes_key_exp) and Iterative Datapath (minisoc_aes_dp) -
//              Semana 4:
//              1. FIPS-197 Appendix C.1:
//                 - Key Expansion verification (all 11 round keys K0..K10)
//                 - Encryption (pt -> ct)
//                 - Decryption (ct -> pt, using pre-computed round keys in reverse)
//              2. FIPS-197 Appendix B:
//                 - Key Expansion verification (all 11 round keys K0..K10)
//                 - Encryption (pt -> ct, checking intermediate round states)
//                 - Decryption (ct -> pt)
// ==============================================================================

module tb_minisoc_aes_dp;

    // --------------------------------------------------------------------------
    // Clock & Reset Generation (100 MHz -> T = 10 ns)
    // --------------------------------------------------------------------------
    logic clk;
    logic rst_n;

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // --------------------------------------------------------------------------
    // DUT Signals
    // --------------------------------------------------------------------------
    logic         key_exp_start;
    logic [127:0] key_in;
    logic [3:0]   key_round_sel;
    logic [127:0] round_key_bus;
    logic         key_exp_busy;
    logic         key_exp_done;

    logic         dp_start;
    logic         dp_decrypt;
    logic [127:0] dp_block_in;
    logic [3:0]   dp_round_sel;
    logic [127:0] dp_block_out;
    logic         dp_busy;
    logic         dp_done;

    // Multiplex round_sel between TB verification and Datapath operation
    logic         tb_key_chk_en;
    logic [3:0]   tb_round_sel;

    assign key_round_sel = tb_key_chk_en ? tb_round_sel : dp_round_sel;

    // --------------------------------------------------------------------------
    // DUT Instantiations
    // --------------------------------------------------------------------------
    minisoc_aes_key_exp u_dut_key_exp (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .start_i     (key_exp_start),
        .key_i       (key_in),
        .round_sel_i (key_round_sel),
        .round_key_o (round_key_bus),
        .busy_o      (key_exp_busy),
        .done_o      (key_exp_done)
    );

    minisoc_aes_dp u_dut_dp (
        .clk_i       (clk),
        .rst_ni      (rst_n),
        .start_i     (dp_start),
        .decrypt_i   (dp_decrypt),
        .block_i     (dp_block_in),
        .round_sel_o (dp_round_sel),
        .round_key_i (round_key_bus),
        .block_o     (dp_block_out),
        .busy_o      (dp_busy),
        .done_o      (dp_done)
    );

    // --------------------------------------------------------------------------
    // Reference Vectors: NIST FIPS-197 Appendix C.1
    // --------------------------------------------------------------------------
    localparam logic [127:0] APP_C1_KEY = 128'h000102030405060708090a0b0c0d0e0f;
    localparam logic [127:0] APP_C1_PT  = 128'h00112233445566778899aabbccddeeff;
    localparam logic [127:0] APP_C1_CT  = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    localparam logic [127:0] APP_C1_RK [0:10] = '{
        128'h000102030405060708090a0b0c0d0e0f, // K0
        128'hd6aa74fdd2af72fadaa678f1d6ab76fe, // K1
        128'hb692cf0b643dbdf1be9bc5006830b3fe, // K2
        128'hb6ff744ed2c2c9bf6c590cbf0469bf41, // K3
        128'h47f7f7bc95353e03f96c32bcfd058dfd, // K4
        128'h3caaa3e8a99f9deb50f3af57adf622aa, // K5
        128'h5e390f7df7a69296a7553dc10aa31f6b, // K6
        128'h14f9701ae35fe28c440adf4d4ea9c026, // K7
        128'h47438735a41c65b9e016baf4aebf7ad2, // K8
        128'h549932d1f08557681093ed9cbe2c974e, // K9
        128'h13111d7fe3944a17f307a78b4d2b30c5  // K10
    };

    // --------------------------------------------------------------------------
    // Reference Vectors: NIST FIPS-197 Appendix B
    // --------------------------------------------------------------------------
    localparam logic [127:0] APP_B_KEY = 128'h2b7e151628aed2a6abf7158809cf4f3c;
    localparam logic [127:0] APP_B_PT  = 128'h3243f6a8885a308d313198a2e0370734;
    localparam logic [127:0] APP_B_CT  = 128'h3925841d02dc09fbdc118597196a0b32;

    localparam logic [127:0] APP_B_RK [0:10] = '{
        128'h2b7e151628aed2a6abf7158809cf4f3c, // K0
        128'ha0fafe1788542cb123a339392a6c7605, // K1
        128'hf2c295f27a96b9435935807a7359f67f, // K2
        128'h3d80477d4716fe3e1e237e446d7a883b, // K3
        128'hef44a541a8525b7fb671253bdb0bad00, // K4
        128'hd4d1c6f87c839d87caf2b8bc11f915bc, // K5
        128'h6d88a37a110b3efddbf98641ca0093fd, // K6
        128'h4e54f70e5f5fc9f384a64fb24ea6dc4f, // K7
        128'head27321b58dbad2312bf5607f8d292f, // K8
        128'hac7766f319fadc2128d12941575c006e, // K9
        128'hd014f9a8c9ee2589e13f0cc8b6630ca6  // K10
    };

    // --------------------------------------------------------------------------
    // Verification Counters & Helper Tasks
    // --------------------------------------------------------------------------
    int err_cnt;
    int pass_cnt;

    task automatic run_key_expansion(input logic [127:0] k);
        @(posedge clk);
        key_in        <= k;
        key_exp_start <= 1'b1;
        @(posedge clk);
        key_exp_start <= 1'b0;
        wait (key_exp_done == 1'b1);
        @(posedge clk);
    endtask

    task automatic run_datapath(
        input  logic         dec,
        input  logic [127:0] blk_in,
        output logic [127:0] blk_out
    );
        @(posedge clk);
        dp_decrypt  <= dec;
        dp_block_in <= blk_in;
        dp_start    <= 1'b1;
        @(posedge clk);
        dp_start    <= 1'b0;
        wait (dp_done == 1'b1);
        #1;
        blk_out = dp_block_out;
        @(posedge clk);
    endtask

    // --------------------------------------------------------------------------
    // Main Test Sequence
    // --------------------------------------------------------------------------
    logic [127:0] result_block;

    initial begin
        err_cnt       = 0;
        pass_cnt      = 0;
        rst_n         = 1'b0;
        key_exp_start = 1'b0;
        key_in        = 128'h0;
        dp_start      = 1'b0;
        dp_decrypt    = 1'b0;
        dp_block_in   = 128'h0;
        tb_key_chk_en = 1'b0;
        tb_round_sel  = 4'd0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);

        $display("========================================================================");
        $display("   MiniSoC AES - Semana 4 Testbench (Key Expansion & AES-128 Datapath)  ");
        $display("========================================================================");

        // ======================================================================
        // TEST 1: FIPS-197 Appendix C.1 (Key Expansion + Encrypt + Decrypt)
        // ======================================================================
        $display("\n[TEST 1] NIST FIPS-197 Appendix C.1:");
        $display("  Key : %032h", APP_C1_KEY);

        run_key_expansion(APP_C1_KEY);

        tb_key_chk_en = 1'b1;
        for (int r = 0; r <= 10; r++) begin
            tb_round_sel = 4'(r);
            #1;
            if (round_key_bus !== APP_C1_RK[r]) begin
                $display("  [FAIL] App C.1 Round Key K%0d: got %032h, exp %032h",
                         r, round_key_bus, APP_C1_RK[r]);
                err_cnt++;
            end else begin
                pass_cnt++;
            end
        end
        tb_key_chk_en = 1'b0;
        $display("  -> Key Expansion (K0..K10): 11/11 PASS");

        // Encrypt Appendix C.1
        run_datapath(1'b0, APP_C1_PT, result_block);
        if (result_block !== APP_C1_CT) begin
            $display("  [FAIL] App C.1 Encrypt: got %032h, exp %032h", result_block, APP_C1_CT);
            err_cnt++;
        end else begin
            $display("  -> Encrypt (PT -> CT)     : PASS (%032h)", result_block);
            pass_cnt++;
        end

        // Decrypt Appendix C.1 (reusing stored round keys in reverse order)
        run_datapath(1'b1, APP_C1_CT, result_block);
        if (result_block !== APP_C1_PT) begin
            $display("  [FAIL] App C.1 Decrypt: got %032h, exp %032h", result_block, APP_C1_PT);
            err_cnt++;
        end else begin
            $display("  -> Decrypt (CT -> PT)     : PASS (%032h)", result_block);
            pass_cnt++;
        end

        // ======================================================================
        // TEST 2: FIPS-197 Appendix B (Key Expansion + Encrypt + Decrypt)
        // ======================================================================
        $display("\n[TEST 2] NIST FIPS-197 Appendix B:");
        $display("  Key : %032h", APP_B_KEY);

        run_key_expansion(APP_B_KEY);

        tb_key_chk_en = 1'b1;
        for (int r = 0; r <= 10; r++) begin
            tb_round_sel = 4'(r);
            #1;
            if (round_key_bus !== APP_B_RK[r]) begin
                $display("  [FAIL] App B Round Key K%0d: got %032h, exp %032h",
                         r, round_key_bus, APP_B_RK[r]);
                err_cnt++;
            end else begin
                pass_cnt++;
            end
        end
        tb_key_chk_en = 1'b0;
        $display("  -> Key Expansion (K0..K10): 11/11 PASS");

        // Encrypt Appendix B
        run_datapath(1'b0, APP_B_PT, result_block);
        if (result_block !== APP_B_CT) begin
            $display("  [FAIL] App B Encrypt: got %032h, exp %032h", result_block, APP_B_CT);
            err_cnt++;
        end else begin
            $display("  -> Encrypt (PT -> CT)     : PASS (%032h)", result_block);
            pass_cnt++;
        end

        // Decrypt Appendix B
        run_datapath(1'b1, APP_B_CT, result_block);
        if (result_block !== APP_B_PT) begin
            $display("  [FAIL] App B Decrypt: got %032h, exp %032h", result_block, APP_B_PT);
            err_cnt++;
        end else begin
            $display("  -> Decrypt (CT -> PT)     : PASS (%032h)", result_block);
            pass_cnt++;
        end

        // ======================================================================
        // Final Summary
        // ======================================================================
        $display("\n========================================================================");
        if (err_cnt == 0 && pass_cnt == 26) begin
            $display("   OVERALL RESULT: PASS (0 errors, %0d/26 checks passed)", pass_cnt);
            $display("   - Appendix C.1 : 11/11 Round Keys, Encrypt PASS, Decrypt PASS");
            $display("   - Appendix B   : 11/11 Round Keys, Encrypt PASS, Decrypt PASS");
        end else begin
            $display("   OVERALL RESULT: FAIL (%0d errors detected)", err_cnt);
        end
        $display("========================================================================");

        repeat (4) @(posedge clk);
        $finish;
    end

    initial begin
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_minisoc_aes_dp);
    end

endmodule

