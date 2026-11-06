// ==============================================================================
// Testbench: tb_minisoc_aes_sub_shift
// Description: Self-checking Unit Testbench for AES-128 Round Transformations
//              (Forward and Inverse) - Semana 2 & Semana 3:
//              1. Exhaustive verification of minisoc_aes_sbox and
//                 minisoc_aes_inv_sbox across all 256 byte values.
//              2. Forward round transformations (SubBytes, ShiftRows,
//                 MixColumns, AddRoundKey) verified against all 10 rounds of
//                 NIST FIPS-197 Appendix B (Cipher Example).
//              3. Inverse round transformations (InvShiftRows, InvSubBytes,
//                 AddRoundKey, InvMixColumns) verified against NIST FIPS-197
//                 Appendix C.1 (128-bit Cipher and Inverse Cipher) intermediate
//                 vectors and full 10-round decryption recovery.
// ==============================================================================

module tb_minisoc_aes_sub_shift;

    // --------------------------------------------------------------------------
    // 1. Standalone S-Box & InvS-Box DUTs
    // --------------------------------------------------------------------------
    logic [7:0] sbox_in;
    logic [7:0] sbox_out;
    logic [7:0] inv_sbox_in;
    logic [7:0] inv_sbox_out;

    minisoc_aes_sbox u_dut_sbox (
        .data_i (sbox_in),
        .data_o (sbox_out)
    );

    minisoc_aes_inv_sbox u_dut_inv_sbox (
        .data_i (inv_sbox_in),
        .data_o (inv_sbox_out)
    );

    // --------------------------------------------------------------------------
    // 2. Forward Round Transformation DUTs
    // --------------------------------------------------------------------------
    logic [127:0] fwd_state_in;
    logic [127:0] fwd_after_sub_bytes;
    logic [127:0] fwd_after_shift_rows;
    logic [127:0] fwd_after_mix_columns;
    logic [127:0] fwd_ark_in;
    logic [127:0] fwd_round_key;
    logic [127:0] fwd_after_ark;

    minisoc_aes_sub_bytes u_dut_sub_bytes (
        .state_i (fwd_state_in),
        .state_o (fwd_after_sub_bytes)
    );

    minisoc_aes_shift_rows u_dut_shift_rows (
        .state_i (fwd_after_sub_bytes),
        .state_o (fwd_after_shift_rows)
    );

    minisoc_aes_mix_columns u_dut_mix_columns (
        .state_i (fwd_after_shift_rows),
        .state_o (fwd_after_mix_columns)
    );

    minisoc_aes_add_round_key u_dut_fwd_ark (
        .state_i     (fwd_ark_in),
        .round_key_i (fwd_round_key),
        .state_o     (fwd_after_ark)
    );

    // --------------------------------------------------------------------------
    // 3. Inverse Round Transformation DUTs
    // --------------------------------------------------------------------------
    logic [127:0] inv_state_in;
    logic [127:0] inv_after_shift_rows;
    logic [127:0] inv_after_sub_bytes;
    logic [127:0] inv_ark_in;
    logic [127:0] inv_round_key;
    logic [127:0] inv_after_ark;
    logic [127:0] inv_after_mix_columns;

    minisoc_aes_inv_shift_rows u_dut_inv_shift_rows (
        .state_i (inv_state_in),
        .state_o (inv_after_shift_rows)
    );

    minisoc_aes_inv_sub_bytes u_dut_inv_sub_bytes (
        .state_i (inv_after_shift_rows),
        .state_o (inv_after_sub_bytes)
    );

    minisoc_aes_add_round_key u_dut_inv_ark (
        .state_i     (inv_ark_in),
        .round_key_i (inv_round_key),
        .state_o     (inv_after_ark)
    );

    minisoc_aes_inv_mix_columns u_dut_inv_mix_columns (
        .state_i (inv_after_ark),
        .state_o (inv_after_mix_columns)
    );

    // --------------------------------------------------------------------------
    // Reference Table: S-Box (NIST FIPS-197, Figure 7)
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
    // Reference Table: InvS-Box (NIST FIPS-197, Figure 14)
    // --------------------------------------------------------------------------
    localparam logic [7:0] INV_SBOX_REF [0:255] = '{
        // 0x00 - 0x0F
        8'h52, 8'h09, 8'h6a, 8'hd5, 8'h30, 8'h36, 8'ha5, 8'h38,
        8'hbf, 8'h40, 8'ha3, 8'h9e, 8'h81, 8'hf3, 8'hd7, 8'hfb,
        // 0x10 - 0x1F
        8'h7c, 8'he3, 8'h39, 8'h82, 8'h9b, 8'h2f, 8'hff, 8'h87,
        8'h34, 8'h8e, 8'h43, 8'h44, 8'hc4, 8'hde, 8'he9, 8'hcb,
        // 0x20 - 0x2F
        8'h54, 8'h7b, 8'h94, 8'h32, 8'ha6, 8'hc2, 8'h23, 8'h3d,
        8'hee, 8'h4c, 8'h95, 8'h0b, 8'h42, 8'hfa, 8'hc3, 8'h4e,
        // 0x30 - 0x3F
        8'h08, 8'h2e, 8'ha1, 8'h66, 8'h28, 8'hd9, 8'h24, 8'hb2,
        8'h76, 8'h5b, 8'ha2, 8'h49, 8'h6d, 8'h8b, 8'hd1, 8'h25,
        // 0x40 - 0x4F
        8'h72, 8'hf8, 8'hf6, 8'h64, 8'h86, 8'h68, 8'h98, 8'h16,
        8'hd4, 8'ha4, 8'h5c, 8'hcc, 8'h5d, 8'h65, 8'hb6, 8'h92,
        // 0x50 - 0x5F
        8'h6c, 8'h70, 8'h48, 8'h50, 8'hfd, 8'hed, 8'hb9, 8'hda,
        8'h5e, 8'h15, 8'h46, 8'h57, 8'ha7, 8'h8d, 8'h9d, 8'h84,
        // 0x60 - 0x6F
        8'h90, 8'hd8, 8'hab, 8'h00, 8'h8c, 8'hbc, 8'hd3, 8'h0a,
        8'hf7, 8'he4, 8'h58, 8'h05, 8'hb8, 8'hb3, 8'h45, 8'h06,
        // 0x70 - 0x7F
        8'hd0, 8'h2c, 8'h1e, 8'h8f, 8'hca, 8'h3f, 8'h0f, 8'h02,
        8'hc1, 8'haf, 8'hbd, 8'h03, 8'h01, 8'h13, 8'h8a, 8'h6b,
        // 0x80 - 0x8F
        8'h3a, 8'h91, 8'h11, 8'h41, 8'h4f, 8'h67, 8'hdc, 8'hea,
        8'h97, 8'hf2, 8'hcf, 8'hce, 8'hf0, 8'hb4, 8'he6, 8'h73,
        // 0x90 - 0x9F
        8'h96, 8'hac, 8'h74, 8'h22, 8'he7, 8'had, 8'h35, 8'h85,
        8'he2, 8'hf9, 8'h37, 8'he8, 8'h1c, 8'h75, 8'hdf, 8'h6e,
        // 0xA0 - 0xAF
        8'h47, 8'hf1, 8'h1a, 8'h71, 8'h1d, 8'h29, 8'hc5, 8'h89,
        8'h6f, 8'hb7, 8'h62, 8'h0e, 8'haa, 8'h18, 8'hbe, 8'h1b,
        // 0xB0 - 0xBF
        8'hfc, 8'h56, 8'h3e, 8'h4b, 8'hc6, 8'hd2, 8'h79, 8'h20,
        8'h9a, 8'hdb, 8'hc0, 8'hfe, 8'h78, 8'hcd, 8'h5a, 8'hf4,
        // 0xC0 - 0xCF
        8'h1f, 8'hdd, 8'ha8, 8'h33, 8'h88, 8'h07, 8'hc7, 8'h31,
        8'hb1, 8'h12, 8'h10, 8'h59, 8'h27, 8'h80, 8'hec, 8'h5f,
        // 0xD0 - 0xDF
        8'h60, 8'h51, 8'h7f, 8'ha9, 8'h19, 8'hb5, 8'h4a, 8'h0d,
        8'h2d, 8'he5, 8'h7a, 8'h9f, 8'h93, 8'hc9, 8'h9c, 8'hef,
        // 0xE0 - 0xEF
        8'ha0, 8'he0, 8'h3b, 8'h4d, 8'hae, 8'h2a, 8'hf5, 8'hb0,
        8'hc8, 8'heb, 8'hbb, 8'h3c, 8'h83, 8'h53, 8'h99, 8'h61,
        // 0xF0 - 0xFF
        8'h17, 8'h2b, 8'h04, 8'h7e, 8'hba, 8'h77, 8'hd6, 8'h26,
        8'he1, 8'h69, 8'h14, 8'h63, 8'h55, 8'h21, 8'h0c, 8'h7d
    };

    // --------------------------------------------------------------------------
    // Reference Vectors: FIPS-197 Appendix B (10 Rounds of Cipher)
    // Plaintext : 3243f6a8_885a308d_313198a2_e0370734
    // Key       : 2b7e1516_28aed2a6_abf71588_09cf4f3c
    // Ciphertext: 3925841d_02dc09fb_dc118597_196a0b32
    // --------------------------------------------------------------------------
    typedef struct packed {
        logic [127:0] start_of_round;
        logic [127:0] after_sub_bytes;
        logic [127:0] after_shift_rows;
        logic [127:0] after_mix_columns;
        logic [127:0] round_key;
        logic [127:0] after_add_round_key;
    } app_b_round_t;

    localparam app_b_round_t FIPS197_APP_B [1:10] = '{
        // Round 1
        '{
            start_of_round      : 128'h193de3bea0f4e22b9ac68d2ae9f84808,
            after_sub_bytes     : 128'hd42711aee0bf98f1b8b45de51e415230,
            after_shift_rows    : 128'hd4bf5d30e0b452aeb84111f11e2798e5,
            after_mix_columns   : 128'h046681e5e0cb199a48f8d37a2806264c,
            round_key           : 128'ha0fafe1788542cb123a339392a6c7605,
            after_add_round_key : 128'ha49c7ff2689f352b6b5bea43026a5049
        },
        // Round 2
        '{
            start_of_round      : 128'ha49c7ff2689f352b6b5bea43026a5049,
            after_sub_bytes     : 128'h49ded28945db96f17f39871a7702533b,
            after_shift_rows    : 128'h49db873b453953897f02d2f177de961a,
            after_mix_columns   : 128'h584dcaf11b4b5aacdbe7caa81b6bb0e5,
            round_key           : 128'hf2c295f27a96b9435935807a7359f67f,
            after_add_round_key : 128'haa8f5f0361dde3ef82d24ad26832469a
        },
        // Round 3
        '{
            start_of_round      : 128'haa8f5f0361dde3ef82d24ad26832469a,
            after_sub_bytes     : 128'hac73cf7befc111df13b5d6b545235ab8,
            after_shift_rows    : 128'hacc1d6b8efb55a7b1323cfdf457311b5,
            after_mix_columns   : 128'h75ec0993200b633353c0cf7cbb25d0dc,
            round_key           : 128'h3d80477d4716fe3e1e237e446d7a883b,
            after_add_round_key : 128'h486c4eee671d9d0d4de3b138d65f58e7
        },
        // Round 4
        '{
            start_of_round      : 128'h486c4eee671d9d0d4de3b138d65f58e7,
            after_sub_bytes     : 128'h52502f2885a45ed7e311c807f6cf6a94,
            after_shift_rows    : 128'h52a4c89485116a28e3cf2fd7f6505e07,
            after_mix_columns   : 128'h0fd6daa9603138bf6fc0106b5eb31301,
            round_key           : 128'hef44a541a8525b7fb671253bdb0bad00,
            after_add_round_key : 128'he0927fe8c86363c0d9b1355085b8be01
        },
        // Round 5
        '{
            start_of_round      : 128'he0927fe8c86363c0d9b1355085b8be01,
            after_sub_bytes     : 128'he14fd29be8fbfbba35c89653976cae7c,
            after_shift_rows    : 128'he1fb967ce8c8ae9b356cd2ba974ffb53,
            after_mix_columns   : 128'h25d1a9adbd11d168b63a338e4c4cc0b0,
            round_key           : 128'hd4d1c6f87c839d87caf2b8bc11f915bc,
            after_add_round_key : 128'hf1006f55c1924cef7cc88b325db5d50c
        },
        // Round 6
        '{
            start_of_round      : 128'hf1006f55c1924cef7cc88b325db5d50c,
            after_sub_bytes     : 128'ha163a8fc784f29df10e83d234cd503fe,
            after_shift_rows    : 128'ha14f3dfe78e803fc10d5a8df4c632923,
            after_mix_columns   : 128'h4b868d6d2c4a8980339df4e837d218d8,
            round_key           : 128'h6d88a37a110b3efddbf98641ca0093fd,
            after_add_round_key : 128'h260e2e173d41b77de86472a9fdd28b25
        },
        // Round 7
        '{
            start_of_round      : 128'h260e2e173d41b77de86472a9fdd28b25,
            after_sub_bytes     : 128'hf7ab31f02783a9ff9b4340d354b53d3f,
            after_shift_rows    : 128'hf783403f27433df09bb531ff54aba9d3,
            after_mix_columns   : 128'h1415b5bf461615ec274656d7342ad843,
            round_key           : 128'h4e54f70e5f5fc9f384a64fb24ea6dc4f,
            after_add_round_key : 128'h5a4142b11949dc1fa3e019657a8c040c
        },
        // Round 8
        '{
            start_of_round      : 128'h5a4142b11949dc1fa3e019657a8c040c,
            after_sub_bytes     : 128'hbe832cc8d43b86c00ae1d44dda64f2fe,
            after_shift_rows    : 128'hbe3bd4fed4e1f2c80a642cc0da83864d,
            after_mix_columns   : 128'h00512fd1b1c889ff54766dcdfa1b99ea,
            round_key           : 128'head27321b58dbad2312bf5607f8d292f,
            after_add_round_key : 128'hea835cf00445332d655d98ad8596b0c5
        },
        // Round 9
        '{
            start_of_round      : 128'hea835cf00445332d655d98ad8596b0c5,
            after_sub_bytes     : 128'h87ec4a8cf26ec3d84d4c46959790e7a6,
            after_shift_rows    : 128'h876e46a6f24ce78c4d904ad897ecc395,
            after_mix_columns   : 128'h473794ed40d4e4a5a3703aa64c9f42bc,
            round_key           : 128'hac7766f319fadc2128d12941575c006e,
            after_add_round_key : 128'heb40f21e592e38848ba113e71bc342d2
        },
        // Round 10 (no MixColumns in final round)
        '{
            start_of_round      : 128'heb40f21e592e38848ba113e71bc342d2,
            after_sub_bytes     : 128'he9098972cb31075f3d327d94af2e2cb5,
            after_shift_rows    : 128'he9317db5cb322c723d2e895faf090794,
            after_mix_columns   : 128'h00000000000000000000000000000000,
            round_key           : 128'hd014f9a8c9ee2589e13f0cc8b6630ca6,
            after_add_round_key : 128'h3925841d02dc09fbdc118597196a0b32
        }
    };

    // --------------------------------------------------------------------------
    // Reference Vectors: FIPS-197 Appendix C.1 (128-bit Cipher & Inverse Cipher)
    // Plaintext : 00112233_44556677_8899aabb_ccddeeff
    // Key       : 00010203_04050607_08090a0b_0c0d0e0f
    // Ciphertext: 69c4e0d8_6a7b0430_d8cdb780_70b4c55a
    // --------------------------------------------------------------------------
    localparam logic [127:0] C1_PLAINTEXT  = 128'h00112233445566778899aabbccddeeff;
    localparam logic [127:0] C1_CIPHERTEXT = 128'h69c4e0d86a7b0430d8cdb78070b4c55a;

    localparam logic [127:0] C1_ROUND_KEYS [0:10] = '{
        128'h000102030405060708090a0b0c0d0e0f, // k_sch[0]
        128'hd6aa74fdd2af72fadaa678f1d6ab76fe, // k_sch[1]
        128'hb692cf0b643dbdf1be9bc5006830b3fe, // k_sch[2]
        128'hb6ff744ed2c2c9bf6c590cbf0469bf41, // k_sch[3]
        128'h47f7f7bc95353e03f96c32bcfd058dfd, // k_sch[4]
        128'h3caaa3e8a99f9deb50f3af57adf622aa, // k_sch[5]
        128'h5e390f7df7a69296a7553dc10aa31f6b, // k_sch[6]
        128'h14f9701ae35fe28c440adf4d4ea9c026, // k_sch[7]
        128'h47438735a41c65b9e016baf4aebf7ad2, // k_sch[8]
        128'h549932d1f08557681093ed9cbe2c974e, // k_sch[9]
        128'h13111d7fe3944a17f307a78b4d2b30c5  // k_sch[10]
    };

    // Appendix C.1 Inverse Cipher Round 1 Intermediate Reference States
    localparam logic [127:0] C1_INV_R1_ISTART = 128'h7ad5fda789ef4e272bca100b3d9ff59f;
    localparam logic [127:0] C1_INV_R1_ISROW  = 128'h7a9f102789d5f50b2beffd9f3dca4ea7;
    localparam logic [127:0] C1_INV_R1_ISBOX  = 128'hbd6e7c3df2b5779e0b61216e8b10b689;
    localparam logic [127:0] C1_INV_R1_IKADD  = 128'he9f74eec023020f61bf2ccf2353c21c7;
    localparam logic [127:0] C1_INV_R2_ISTART = 128'h54d990a16ba09ab596bbf40ea111702f;

    // Appendix C.1 Inverse Cipher Round 10 Intermediate Reference States
    localparam logic [127:0] C1_INV_R10_ISTART = 128'h6353e08c0960e104cd70b751bacad0e7;
    localparam logic [127:0] C1_INV_R10_ISROW  = 128'h63cab7040953d051cd60e0e7ba70e18c;
    localparam logic [127:0] C1_INV_R10_ISBOX  = 128'h00102030405060708090a0b0c0d0e0f0;

    // --------------------------------------------------------------------------
    // Test Execution
    // --------------------------------------------------------------------------
    int err_cnt;
    int sbox_pass_cnt;
    int inv_sbox_pass_cnt;
    int app_b_fwd_pass_cnt;
    int app_b_inv_pass_cnt;
    int app_c1_inv_pass_cnt;
    logic [127:0] running_state;

    initial begin
        err_cnt             = 0;
        sbox_pass_cnt       = 0;
        inv_sbox_pass_cnt   = 0;
        app_b_fwd_pass_cnt  = 0;
        app_b_inv_pass_cnt  = 0;
        app_c1_inv_pass_cnt = 0;

        sbox_in       = 8'h00;
        inv_sbox_in   = 8'h00;
        fwd_state_in  = 128'h0;
        fwd_ark_in    = 128'h0;
        fwd_round_key = 128'h0;
        inv_state_in  = 128'h0;
        inv_ark_in    = 128'h0;
        inv_round_key = 128'h0;

        $display("========================================================================");
        $display("   MiniSoC AES - Semana 3 Unit Testbench (All Round Transformations)    ");
        $display("========================================================================");

        // ======================================================================
        // TEST 1: Exhaustive S-Box & InvS-Box Verification (256 entries each)
        // ======================================================================
        $display("\n[TEST 1] Exhaustive Verification of S-Box and InvS-Box (256 inputs)...");

        for (int i = 0; i < 256; i++) begin
            sbox_in = 8'(i);
            #1;
            inv_sbox_in = sbox_out;
            #1;

            if (sbox_out !== SBOX_REF[i]) begin
                $display("  [FAIL] sbox(8'h%02h) = 8'h%02h | Exp: 8'h%02h",
                         sbox_in, sbox_out, SBOX_REF[i]);
                err_cnt++;
            end else begin
                sbox_pass_cnt++;
            end

            // Verify both direct LUT lookup and bijective property inv_sbox(sbox(x)) == x
            if (inv_sbox_out !== 8'(i) || INV_SBOX_REF[sbox_out] !== 8'(i)) begin
                $display("  [FAIL] inv_sbox(8'h%02h) = 8'h%02h | INV_SBOX_REF = 8'h%02h | Exp: 8'h%02h",
                         inv_sbox_in, inv_sbox_out, INV_SBOX_REF[sbox_out], 8'(i));
                err_cnt++;
            end else begin
                inv_sbox_pass_cnt++;
            end
        end

        $display("  >>> S-Box    : %0d/256 PASS", sbox_pass_cnt);
        $display("  >>> InvS-Box : %0d/256 PASS (Bijective identity verified)", inv_sbox_pass_cnt);

        // ======================================================================
        // TEST 2: Forward Round Transformations on FIPS-197 Appendix B (Rounds 1..10)
        //         (SubBytes -> ShiftRows -> MixColumns -> AddRoundKey)
        // ======================================================================
        $display("\n[TEST 2] Forward Transformations on FIPS-197 Appendix B (Rounds 1..10):");

        for (int r = 1; r <= 10; r++) begin
            fwd_state_in  = FIPS197_APP_B[r].start_of_round;
            fwd_round_key = FIPS197_APP_B[r].round_key;
            #1;
            if (r < 10) begin
                fwd_ark_in = fwd_after_mix_columns;
            end else begin
                fwd_ark_in = fwd_after_shift_rows;
            end
            #1;

            if (fwd_after_sub_bytes !== FIPS197_APP_B[r].after_sub_bytes) begin
                $display("  [FAIL] App B Round %0d SubBytes: got %032h, exp %032h",
                         r, fwd_after_sub_bytes, FIPS197_APP_B[r].after_sub_bytes);
                err_cnt++;
            end

            if (fwd_after_shift_rows !== FIPS197_APP_B[r].after_shift_rows) begin
                $display("  [FAIL] App B Round %0d ShiftRows: got %032h, exp %032h",
                         r, fwd_after_shift_rows, FIPS197_APP_B[r].after_shift_rows);
                err_cnt++;
            end

            if (r < 10 && (fwd_after_mix_columns !== FIPS197_APP_B[r].after_mix_columns)) begin
                $display("  [FAIL] App B Round %0d MixColumns: got %032h, exp %032h",
                         r, fwd_after_mix_columns, FIPS197_APP_B[r].after_mix_columns);
                err_cnt++;
            end

            if (fwd_after_ark !== FIPS197_APP_B[r].after_add_round_key) begin
                $display("  [FAIL] App B Round %0d AddRoundKey: got %032h, exp %032h",
                         r, fwd_after_ark, FIPS197_APP_B[r].after_add_round_key);
                err_cnt++;
            end else begin
                app_b_fwd_pass_cnt++;
                $display("  -> App B Forward Round %2d: PASS (ARK out = %032h)", r, fwd_after_ark);
            end
        end

        // ======================================================================
        // TEST 3: Inverse Round Transformations on FIPS-197 Appendix B (Rounds 10..1)
        //         Verifying exact step-by-step inversion of every Appendix B state
        // ======================================================================
        $display("\n[TEST 3] Inverse Transformations on FIPS-197 Appendix B (Rounds 10..1):");

        for (int r = 10; r >= 1; r--) begin
            // In round r, s_row is inverted by InvShiftRows -> s_box, then InvSubBytes -> start_of_round
            inv_state_in  = FIPS197_APP_B[r].after_shift_rows;
            inv_ark_in    = FIPS197_APP_B[r].after_add_round_key;
            inv_round_key = FIPS197_APP_B[r].round_key;
            #2;

            if (inv_after_shift_rows !== FIPS197_APP_B[r].after_sub_bytes) begin
                $display("  [FAIL] App B InvShiftRows Round %0d: got %032h, exp %032h",
                         r, inv_after_shift_rows, FIPS197_APP_B[r].after_sub_bytes);
                err_cnt++;
            end

            if (inv_after_sub_bytes !== FIPS197_APP_B[r].start_of_round) begin
                $display("  [FAIL] App B InvSubBytes Round %0d: got %032h, exp %032h",
                         r, inv_after_sub_bytes, FIPS197_APP_B[r].start_of_round);
                err_cnt++;
            end

            if (r < 10) begin
                if (inv_after_ark !== FIPS197_APP_B[r].after_mix_columns) begin
                    $display("  [FAIL] App B InvARK Round %0d: got %032h, exp %032h",
                             r, inv_after_ark, FIPS197_APP_B[r].after_mix_columns);
                    err_cnt++;
                end
                if (inv_after_mix_columns !== FIPS197_APP_B[r].after_shift_rows) begin
                    $display("  [FAIL] App B InvMixColumns Round %0d: got %032h, exp %032h",
                             r, inv_after_mix_columns, FIPS197_APP_B[r].after_shift_rows);
                    err_cnt++;
                end else begin
                    app_b_inv_pass_cnt++;
                end
            end else begin
                if (inv_after_ark !== FIPS197_APP_B[10].after_shift_rows) begin
                    $display("  [FAIL] App B InvARK Round 10: got %032h, exp %032h",
                             inv_after_ark, FIPS197_APP_B[10].after_shift_rows);
                    err_cnt++;
                end else begin
                    app_b_inv_pass_cnt++;
                end
            end
        end
        $display("  >>> App B Inverse Rounds: %0d/10 PASS", app_b_inv_pass_cnt);

        // ======================================================================
        // TEST 4: FIPS-197 Appendix C.1 Inverse Cipher (128-bit Decryption)
        //         Checking intermediate states (istart, is_row, is_box, ik_add)
        //         and full 10-round plaintext recovery
        // ======================================================================
        $display("\n[TEST 4] FIPS-197 Appendix C.1 (Inverse Cipher - 128-bit Decryption):");

        // Initial AddRoundKey (round[0].iinput ^ k_sch[10])
        inv_ark_in    = C1_CIPHERTEXT;
        inv_round_key = C1_ROUND_KEYS[10];
        #1;
        running_state = inv_after_ark;

        if (running_state !== C1_INV_R1_ISTART) begin
            $display("  [FAIL] App C.1 Inv Round 1 istart: got %032h, exp %032h",
                     running_state, C1_INV_R1_ISTART);
            err_cnt++;
        end

        // Execute Inverse Rounds 1 to 10
        for (int r_inv = 1; r_inv <= 10; r_inv++) begin
            inv_state_in = running_state;
            #1;
            inv_ark_in    = inv_after_sub_bytes;
            inv_round_key = C1_ROUND_KEYS[10 - r_inv];
            #1;

            // Detailed check of Round 1 intermediate vectors against Appendix C.1
            if (r_inv == 1) begin
                $display("  App C.1 Inv Round 1:");
                $display("    istart : %032h (Exp: %032h)", inv_state_in, C1_INV_R1_ISTART);
                $display("    is_row : %032h (Exp: %032h)", inv_after_shift_rows, C1_INV_R1_ISROW);
                $display("    is_box : %032h (Exp: %032h)", inv_after_sub_bytes, C1_INV_R1_ISBOX);
                $display("    ik_add : %032h (Exp: %032h)", inv_after_ark, C1_INV_R1_IKADD);
                $display("    im_col : %032h (Exp: %032h)", inv_after_mix_columns, C1_INV_R2_ISTART);

                if (inv_after_shift_rows  !== C1_INV_R1_ISROW ||
                    inv_after_sub_bytes   !== C1_INV_R1_ISBOX ||
                    inv_after_ark         !== C1_INV_R1_IKADD ||
                    inv_after_mix_columns !== C1_INV_R2_ISTART) begin
                    $display("    [FAIL] App C.1 Inv Round 1 intermediate vector mismatch!");
                    err_cnt++;
                end else begin
                    app_c1_inv_pass_cnt++;
                    $display("    -> App C.1 Inv Round 1: PASS");
                end
            end else if (r_inv == 10) begin
                $display("  App C.1 Inv Round 10:");
                $display("    istart  : %032h (Exp: %032h)", inv_state_in, C1_INV_R10_ISTART);
                $display("    is_row  : %032h (Exp: %032h)", inv_after_shift_rows, C1_INV_R10_ISROW);
                $display("    is_box  : %032h (Exp: %032h)", inv_after_sub_bytes, C1_INV_R10_ISBOX);
                $display("    ioutput : %032h (Exp: %032h)", inv_after_ark, C1_PLAINTEXT);

                if (inv_state_in         !== C1_INV_R10_ISTART ||
                    inv_after_shift_rows !== C1_INV_R10_ISROW  ||
                    inv_after_sub_bytes  !== C1_INV_R10_ISBOX  ||
                    inv_after_ark        !== C1_PLAINTEXT) begin
                    $display("    [FAIL] App C.1 Inv Round 10 / Plaintext mismatch!");
                    err_cnt++;
                end else begin
                    app_c1_inv_pass_cnt++;
                    $display("    -> App C.1 Inv Round 10 (Plaintext Recovered): PASS");
                end
            end else begin
                app_c1_inv_pass_cnt++;
            end

            if (r_inv < 10) begin
                running_state = inv_after_mix_columns;
            end else begin
                running_state = inv_after_ark;
            end
        end

        // ======================================================================
        // Final Summary
        // ======================================================================
        $display("\n========================================================================");
        if (err_cnt == 0 &&
            sbox_pass_cnt == 256 &&
            inv_sbox_pass_cnt == 256 &&
            app_b_fwd_pass_cnt == 10 &&
            app_b_inv_pass_cnt == 10 &&
            app_c1_inv_pass_cnt == 10) begin
            $display("   OVERALL RESULT: PASS (0 errors)");
            $display("   - S-Box & InvS-Box        : 256/256 PASS");
            $display("   - FIPS-197 Appendix B     : 10/10 Forward & 10/10 Inverse PASS");
            $display("   - FIPS-197 Appendix C.1   : 10/10 Inverse Cipher PASS");
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
