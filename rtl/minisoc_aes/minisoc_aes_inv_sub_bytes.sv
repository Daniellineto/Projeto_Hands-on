// ==============================================================================
// Module: minisoc_aes_inv_sub_bytes
// Description: AES InvSubBytes Transformation - 16 parallel instances of InvS-Box.
//              State convention: byte 0 at [127:120], byte 15 at [7:0].
// Reference: NIST FIPS-197, Section 5.3.2.
// ==============================================================================

module minisoc_aes_inv_sub_bytes (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    genvar n;
    generate
        for (n = 0; n < 16; n++) begin : gen_inv_sbox
            minisoc_aes_inv_sbox u_inv_sbox (
                .data_i (state_i[127 - 8*n -: 8]),
                .data_o (state_o[127 - 8*n -: 8])
            );
        end
    endgenerate

endmodule

