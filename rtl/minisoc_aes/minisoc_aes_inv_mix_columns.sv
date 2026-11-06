// ==============================================================================
// Module: minisoc_aes_inv_mix_columns
// Description: AES InvMixColumns Transformation - Combinational inverse matrix
//              multiplication over GF(2^8) with polynomial m(x) = x^8+x^4+x^3+x+1.
//              State convention: Column c (0..3) at state[127 - 32*c -: 32].
// Reference: NIST FIPS-197, Section 5.3.3.
// ==============================================================================

module minisoc_aes_inv_mix_columns (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    // Multiplication by {02} (x) in GF(2^8) modulo 0x11b
    function automatic logic [7:0] xtime(input logic [7:0] b);
        xtime = {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    // Multiplication by {09} = {08} ^ {01}
    function automatic logic [7:0] mul09(input logic [7:0] b);
        logic [7:0] x2, x4, x8;
        begin
            x2    = xtime(b);
            x4    = xtime(x2);
            x8    = xtime(x4);
            mul09 = x8 ^ b;
        end
    endfunction

    // Multiplication by {0b} = {08} ^ {02} ^ {01}
    function automatic logic [7:0] mul0b(input logic [7:0] b);
        logic [7:0] x2, x4, x8;
        begin
            x2    = xtime(b);
            x4    = xtime(x2);
            x8    = xtime(x4);
            mul0b = x8 ^ x2 ^ b;
        end
    endfunction

    // Multiplication by {0d} = {08} ^ {04} ^ {01}
    function automatic logic [7:0] mul0d(input logic [7:0] b);
        logic [7:0] x2, x4, x8;
        begin
            x2    = xtime(b);
            x4    = xtime(x2);
            x8    = xtime(x4);
            mul0d = x8 ^ x4 ^ b;
        end
    endfunction

    // Multiplication by {0e} = {08} ^ {04} ^ {02}
    function automatic logic [7:0] mul0e(input logic [7:0] b);
        logic [7:0] x2, x4, x8;
        begin
            x2    = xtime(b);
            x4    = xtime(x2);
            x8    = xtime(x4);
            mul0e = x8 ^ x4 ^ x2;
        end
    endfunction

    // Single column InvMixColumns transformation (32-bit word: {s0, s1, s2, s3})
    function automatic logic [31:0] inv_mix_col(input logic [31:0] col);
        logic [7:0] s0, s1, s2, s3;
        logic [7:0] r0, r1, r2, r3;
        begin
            s0 = col[31:24];
            s1 = col[23:16];
            s2 = col[15:8];
            s3 = col[7:0];

            r0 = mul0e(s0) ^ mul0b(s1) ^ mul0d(s2) ^ mul09(s3);
            r1 = mul09(s0) ^ mul0e(s1) ^ mul0b(s2) ^ mul0d(s3);
            r2 = mul0d(s0) ^ mul09(s1) ^ mul0e(s2) ^ mul0b(s3);
            r3 = mul0b(s0) ^ mul0d(s1) ^ mul09(s2) ^ mul0e(s3);

            inv_mix_col = {r0, r1, r2, r3};
        end
    endfunction

    always_comb begin
        state_o[127:96] = inv_mix_col(state_i[127:96]); // Column 0 (Word 0)
        state_o[95:64]  = inv_mix_col(state_i[95:64]);  // Column 1 (Word 1)
        state_o[63:32]  = inv_mix_col(state_i[63:32]);  // Column 2 (Word 2)
        state_o[31:0]   = inv_mix_col(state_i[31:0]);   // Column 3 (Word 3)
    end

endmodule

