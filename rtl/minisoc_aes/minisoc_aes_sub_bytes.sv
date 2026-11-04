// ==============================================================================
// Module: minisoc_aes_sub_bytes
// Description: AES SubBytes Transformation - 16 parallel instances of S-Box.
//              State convention: byte 0 at [127:120], byte 15 at [7:0].
//              Byte n corresponds to s[r][c] with r = n mod 4, c = n div 4.
// Reference: NIST FIPS-197, Section 5.1.1 & Block Guide MiniSoC AES, Section 7.1
// ==============================================================================

module minisoc_aes_sub_bytes (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    genvar n;
    generate
        for (n = 0; n < 16; n++) begin : gen_sbox
            minisoc_aes_sbox u_sbox (
                .data_i (state_i[127 - 8*n -: 8]),
                .data_o (state_o[127 - 8*n -: 8])
            );
        end
    endgenerate

endmodule

