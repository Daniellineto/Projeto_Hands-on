// ==============================================================================
// Module: minisoc_aes_mix_columns
// Description: AES MixColumns Transformation - Combinational matrix multiplication
//              over GF(2^8) with irreducible polynomial m(x) = x^8 + x^4 + x^3 + x + 1.
//              State convention: Column c (0..3) at state[127 - 32*c -: 32].
// Reference: NIST FIPS-197, Section 5.1.3.
// ==============================================================================

module minisoc_aes_mix_columns (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    // Multiplication by {02} (x) in GF(2^8) modulo 0x11b
    function automatic logic [7:0] xtime(input logic [7:0] b);
        xtime = {b[6:0], 1'b0} ^ (b[7] ? 8'h1b : 8'h00);
    endfunction

    // Single column MixColumns transformation (32-bit word: {s0, s1, s2, s3})
    function automatic logic [31:0] mix_col(input logic [31:0] col);
        logic [7:0] s0, s1, s2, s3;
        logic [7:0] r0, r1, r2, r3;
        begin
            s0 = col[31:24];
            s1 = col[23:16];
            s2 = col[15:8];
            s3 = col[7:0];

            r0 = xtime(s0 ^ s1) ^ s1 ^ s2 ^ s3;
            r1 = s0 ^ xtime(s1 ^ s2) ^ s2 ^ s3;
            r2 = s0 ^ s1 ^ xtime(s2 ^ s3) ^ s3;
            r3 = xtime(s3 ^ s0) ^ s0 ^ s1 ^ s2;

            mix_col = {r0, r1, r2, r3};
        end
    endfunction

    always_comb begin
        state_o[127:96] = mix_col(state_i[127:96]); // Column 0 (Word 0)
        state_o[95:64]  = mix_col(state_i[95:64]);  // Column 1 (Word 1)
        state_o[63:32]  = mix_col(state_i[63:32]);  // Column 2 (Word 2)
        state_o[31:0]   = mix_col(state_i[31:0]);   // Column 3 (Word 3)
    end

endmodule

