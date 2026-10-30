// ==============================================================================
// Testbench: tb_minisoc_aes_sub_shift
// Description: Self-checking testbench for Semana 2 Challenge:
//              (a) Exhaustive verification of minisoc_aes_sbox across all 256
//                  inputs against the NIST FIPS-197 Figure 7 reference table
//                  (including explicit checks for 8'h00 -> 8'h63 and 8'h53 -> 8'hed).
//              (b) Verification of minisoc_aes_sub_bytes and minisoc_aes_shift_rows
//                  chained together ("Start of Round" -> "After SubBytes" ->
//                  "After ShiftRows") across all 10 rounds (Rounds 1 to 10) of
//                  the NIST FIPS-197 Appendix B cipher example.
// ==============================================================================

module tb_minisoc_aes_sub_shift;

    // --------------------------------------------------------------------------
    // Signals for standalone S-Box DUT
    // --------------------------------------------------------------------------
    logic [7:0] sbox_in;
    logic [7:0] sbox_out;

    minisoc_aes_sbox u_dut_sbox (
        .data_i (sbox_in),
        .data_o (sbox_out)
    );

    // --------------------------------------------------------------------------
    // Signals for SubBytes and ShiftRows DUTs (Start -> SubBytes -> ShiftRows)
    // --------------------------------------------------------------------------
    logic [127:0] state_start_round;
    logic [127:0] state_after_sub_bytes;
    logic [127:0] state_after_shift_rows;

    minisoc_aes_sub_bytes u_dut_sub_bytes (
        .state_i (state_start_round),
        .state_o (state_after_sub_bytes)
    );

    minisoc_aes_shift_rows u_dut_shift_rows (
        .state_i (state_after_sub_bytes),
        .state_o (state_after_shift_rows)
    );

    // --------------------------------------------------------------------------
    // Reference Table for S-Box (NIST FIPS-197, Figure 7)
    // --------------------------------------------------------------------------
    localparam logic [7:0] SBOX_REF [0:255] = '{
        // 0x00 - 0x0F
        8'h63, 8'h7c, 8'h77, 8'h7b, 8'hf2, 8'h6b, 8'h6f, 8'hc5,
        8'h30, 8'h01, 8'h67, 8'h2b, 8'hfe, 8'hd7, 8'hab, 8'h76,
        // 0x10 - 0x1F
        8'hca, 8'h82, 8'hc9, 8'h7d, 8'hfa, 8'h59, 8'h47, 8'hf0,
        8'had, 8'hd4, 8'ha2, 8'haf, 8'h9c, 8'ha4, 8'h72, 8'hc0,
        // 0x20 - 0x2F
        8'hb7, 8'hfd, 8'h93, 8'h26, 8'h36, 8'h3f, 8'hf7, 8'hcc,
        8'h34, 8'ha5, 8'he5, 8'hf1, 8'h71, 8'hd8, 8'h31, 8'h15,
        // 0x30 - 0x3F
        8'h04, 8'hc7, 8'h23, 8'hc3, 8'h18, 8'h96, 8'h05, 8'h9a,
        8'h07, 8'h12, 8'h80, 8'he2, 8'heb, 8'h27, 8'hb2, 8'h75,
        // 0x40 - 0x4F
        8'h09, 8'h83, 8'h2c, 8'h1a, 8'h1b, 8'h6e, 8'h5a, 8'ha0,
        8'h52, 8'h3b, 8'hd6, 8'hb3, 8'h29, 8'he3, 8'h2f, 8'h84,
        // 0x50 - 0x5F
        8'h53, 8'hd1, 8'h00, 8'hed, 8'h20, 8'hfc, 8'hb1, 8'h5b,
        8'h6a, 8'hcb, 8'hbe, 8'h39, 8'h4a, 8'h4c, 8'h58, 8'hcf,
        // 0x60 - 0x6F
        8'hd0, 8'hef, 8'haa, 8'hfb, 8'h43, 8'h4d, 8'h33, 8'h85,
        8'h45, 8'hf9, 8'h02, 8'h7f, 8'h50, 8'h3c, 8'h9f, 8'ha8,
        // 0x70 - 0x7F
        8'h51, 8'ha3, 8'h40, 8'h8f, 8'h92, 8'h9d, 8'h38, 8'hf5,
        8'hbc, 8'hb6, 8'hda, 8'h21, 8'h10, 8'hff, 8'hf3, 8'hd2,
        // 0x80 - 0x8F
        8'hcd, 8'h0c, 8'h13, 8'hec, 8'h5f, 8'h97, 8'h44, 8'h17,
        8'hc4, 8'ha7, 8'h7e, 8'h3d, 8'h64, 8'h5d, 8'h19, 8'h73,
        // 0x90 - 0x9F
        8'h60, 8'h81, 8'h4f, 8'hdc, 8'h22, 8'h2a, 8'h90, 8'h88,
        8'h46, 8'hee, 8'hb8, 8'h14, 8'hde, 8'h5e, 8'h0b, 8'hdb,
        // 0xA0 - 0xAF
        8'he0, 8'h32, 8'h3a, 8'h0a, 8'h49, 8'h06, 8'h24, 8'h5c,
        8'hc2, 8'hd3, 8'hac, 8'h62, 8'h91, 8'h95, 8'he4, 8'h79,
        // 0xB0 - 0xBF
        8'he7, 8'hc8, 8'h37, 8'h6d, 8'h8d, 8'hd5, 8'h4e, 8'ha9,
        8'h6c, 8'h56, 8'hf4, 8'hea, 8'h65, 8'h7a, 8'hae, 8'h08,
        // 0xC0 - 0xCF
        8'hba, 8'h78, 8'h25, 8'h2e, 8'h1c, 8'ha6, 8'hb4, 8'hc6,
        8'he8, 8'hdd, 8'h74, 8'h1f, 8'h4b, 8'hbd, 8'h8b, 8'h8a,
        // 0xD0 - 0xDF
        8'h70, 8'h3e, 8'hb5, 8'h66, 8'h48, 8'h03, 8'hf6, 8'h0e,
        8'h61, 8'h35, 8'h57, 8'hb9, 8'h86, 8'hc1, 8'h1d, 8'h9e,
        // 0xE0 - 0xEF
        8'he1, 8'hf8, 8'h98, 8'h11, 8'h69, 8'hd9, 8'h8e, 8'h94,
        8'h9b, 8'h1e, 8'h87, 8'he9, 8'hce, 8'h55, 8'h28, 8'hdf,
        // 0xF0 - 0xFF
        8'h8c, 8'ha1, 8'h89, 8'h0d, 8'hbf, 8'he6, 8'h42, 8'h68,
        8'h41, 8'h99, 8'h2d, 8'h0f, 8'hb0, 8'h54, 8'hbb, 8'h16
    };

    // --------------------------------------------------------------------------
    // Reference Vectors for FIPS-197 Appendix B (Rounds 1 to 10)
    // --------------------------------------------------------------------------
    typedef struct packed {
        logic [127:0] start_of_round;
        logic [127:0] after_sub_bytes;
        logic [127:0] after_shift_rows;
    } round_vec_t;

    localparam round_vec_t FIPS197_APP_B [1:10] = '{
        // Round 1
        '{
            start_of_round   : 128'h193de3bea0f4e22b9ac68d2ae9f84808,
            after_sub_bytes  : 128'hd42711aee0bf98f1b8b45de51e415230,
            after_shift_rows : 128'hd4bf5d30e0b452aeb84111f11e2798e5
        },
        // Round 2
        '{
            start_of_round   : 128'ha49c7ff2689f352b6b5bea43026a5049,
            after_sub_bytes  : 128'h49ded28945db96f17f39871a7702533b,
            after_shift_rows : 128'h49db873b453953897f02d2f177de961a
        },
        // Round 3
        '{
            start_of_round   : 128'haa8f5f0361dde3ef82d24ad26832469a,
            after_sub_bytes  : 128'hac73cf7befc111df13b5d6b545235ab8,
            after_shift_rows : 128'hacc1d6b8efb55a7b1323cfdf457311b5
        },
        // Round 4
        '{
            start_of_round   : 128'h486c4eee671d9d0d4de3b138d65f58e7,
            after_sub_bytes  : 128'h52502f2885a45ed7e311c807f6cf6a94,
            after_shift_rows : 128'h52a4c89485116a28e3cf2fd7f6505e07
        },
        // Round 5
        '{
            start_of_round   : 128'he0927fe8c86363c0d9b1355085b8be01,
            after_sub_bytes  : 128'he14fd29be8fbfbba35c89653976cae7c,
            after_shift_rows : 128'he1fb967ce8c8ae9b356cd2ba974ffb53
        },
        // Round 6
        '{
            start_of_round   : 128'hf1006f55c1924cef7cc88b325db5d50c,
            after_sub_bytes  : 128'ha163a8fc784f29df10e83d234cd503fe,
            after_shift_rows : 128'ha14f3dfe78e803fc10d5a8df4c632923
        },
        // Round 7
        '{
            start_of_round   : 128'h260e2e173d41b77de86472a9fdd28b25,
            after_sub_bytes  : 128'hf7ab31f02783a9ff9b4340d354b53d3f,
            after_shift_rows : 128'hf783403f27433df09bb531ff54aba9d3
        },
        // Round 8
        '{
            start_of_round   : 128'h5a4142b11949dc1fa3e019657a8c040c,
            after_sub_bytes  : 128'hbe832cc8d43b86c00ae1d44dda64f2fe,
            after_shift_rows : 128'hbe3bd4fed4e1f2c80a642cc0da83864d
        },
        // Round 9
        '{
            start_of_round   : 128'hea835cf00445332d655d98ad8596b0c5,
            after_sub_bytes  : 128'h87ec4a8cf26ec3d84d4c46959790e7a6,
            after_shift_rows : 128'h876e46a6f24ce78c4d904ad897ecc395
        },
        // Round 10
        '{
            start_of_round   : 128'heb40f21e592e38848ba113e71bc342d2,
            after_sub_bytes  : 128'he9098972cb31075f3d327d94af2e2cb5,
            after_shift_rows : 128'he9317db5cb322c723d2e895faf090794
        }
    };

    // --------------------------------------------------------------------------
    // Test Execution
    // --------------------------------------------------------------------------
    int err_cnt;
    int sbox_pass_cnt;
    int round_pass_cnt;

    initial begin
        err_cnt        = 0;
        sbox_pass_cnt  = 0;
        round_pass_cnt = 0;
        sbox_in        = 8'h00;
        state_start_round = 128'h0;

        $display("========================================================================");
        $display("   MiniSoC AES - Semana 2 Testbench (S-Box, SubBytes & ShiftRows)       ");
        $display("========================================================================");

        // ----------------------------------------------------------------------
        // Part (a): Exhaustive S-Box Test (256 inputs)
        // ----------------------------------------------------------------------
        $display("\n[TEST A] Exhaustive Verification of minisoc_aes_sbox (256 entries)...");

        for (int i = 0; i < 256; i++) begin
            sbox_in = 8'(i);
            #1;
            if (sbox_out !== SBOX_REF[i]) begin
                $display("  [FAIL] sbox(8'h%02h) = 8'h%02h | Expected: 8'h%02h",
                         sbox_in, sbox_out, SBOX_REF[i]);
                err_cnt++;
            end else begin
                sbox_pass_cnt++;
                if (sbox_in == 8'h00 || sbox_in == 8'h53) begin
                    $display("  [CHECK] sbox(8'h%02h) = 8'h%02h (Expected: 8'h%02h) -> OK",
                             sbox_in, sbox_out, SBOX_REF[i]);
                end
            end
        end

        if (sbox_pass_cnt == 256) begin
            $display("  >>> [PASS] S-Box passed 256/256 exhaustive vectors.");
        end else begin
            $display("  >>> [FAIL] S-Box passed %0d/256 vectors.", sbox_pass_cnt);
        end

        // ----------------------------------------------------------------------
        // Part (b): SubBytes & ShiftRows on FIPS-197 Appendix B (Rounds 1..10)
        // ----------------------------------------------------------------------
        $display("\n[TEST B] Verification of minisoc_aes_sub_bytes & minisoc_aes_shift_rows");
        $display("         using NIST FIPS-197 Appendix B Cipher Example (Rounds 1 to 10):");

        for (int r = 1; r <= 10; r++) begin
            state_start_round = FIPS197_APP_B[r].start_of_round;
            #5;

            $display("  Round %2d:", r);
            $display("    Start of Round : %032h", state_start_round);
            $display("    After SubBytes : %032h (Exp: %032h)",
                     state_after_sub_bytes, FIPS197_APP_B[r].after_sub_bytes);
            $display("    After ShiftRows: %032h (Exp: %032h)",
                     state_after_shift_rows, FIPS197_APP_B[r].after_shift_rows);

            if (state_after_sub_bytes !== FIPS197_APP_B[r].after_sub_bytes) begin
                $display("    [FAIL] Round %0d SubBytes mismatch!", r);
                err_cnt++;
            end

            if (state_after_shift_rows !== FIPS197_APP_B[r].after_shift_rows) begin
                $display("    [FAIL] Round %0d ShiftRows mismatch!", r);
                err_cnt++;
            end

            if ((state_after_sub_bytes  === FIPS197_APP_B[r].after_sub_bytes) &&
                (state_after_shift_rows === FIPS197_APP_B[r].after_shift_rows)) begin
                $display("    -> Round %0d: PASS", r);
                round_pass_cnt++;
            end
        end

        // ----------------------------------------------------------------------
        // Final Summary
        // ----------------------------------------------------------------------
        $display("\n========================================================================");
        if (err_cnt == 0 && sbox_pass_cnt == 256 && round_pass_cnt == 10) begin
            $display("   OVERALL RESULT: PASS (S-Box: 256/256 | Appendix B Rounds: 10/10)");
        end else begin
            $display("   OVERALL RESULT: FAIL (%0d errors detected)", err_cnt);
        end
        $display("========================================================================");

        #10;
        $finish;
    end

    initial begin
        $fsdbDumpfile("waves.fsdb");
        $fsdbDumpvars(0, tb_minisoc_aes_sub_shift);
    end

endmodule
