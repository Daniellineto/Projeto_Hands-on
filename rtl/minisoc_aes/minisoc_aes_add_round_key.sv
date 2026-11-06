// ==============================================================================
// Module: minisoc_aes_add_round_key
// Description: AES AddRoundKey Transformation - Combinational 128-bit XOR
//              between the state matrix and the round key.
//              Self-inverse operation (used in both Cipher and Inverse Cipher).
// Reference: NIST FIPS-197, Sections 5.1.4 and 5.3.4.
// ==============================================================================

module minisoc_aes_add_round_key (
    input  logic [127:0] state_i,
    input  logic [127:0] round_key_i,
    output logic [127:0] state_o
);

    assign state_o = state_i ^ round_key_i;

endmodule

