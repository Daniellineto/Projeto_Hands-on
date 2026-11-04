// ==============================================================================
// Module: minisoc_aes_shift_rows
// Description: AES ShiftRows Transformation - Purely combinational wire reordering.
//              State convention: byte 0 at [127:120], byte 15 at [7:0].
//              Byte n corresponds to s[r][c] with r = n mod 4, c = n div 4.
//              Transformation: s'[r][c] = s[r][(c + r) mod 4].
// Reference: NIST FIPS-197, Section 5.1.2 & Block Guide MiniSoC AES, Section 7.1
// ==============================================================================

module minisoc_aes_shift_rows (
    input  logic [127:0] state_i,
    output logic [127:0] state_o
);

    // Column 0 (Word 0: [127:96]) -> {s[0][0], s[1][1], s[2][2], s[3][3]} = {b0, b5, b10, b15}
    assign state_o[127:120] = state_i[127:120]; // b0  (r=0, c=0)
    assign state_o[119:112] = state_i[87:80];   // b5  (r=1, c=1)
    assign state_o[111:104] = state_i[47:40];   // b10 (r=2, c=2)
    assign state_o[103:96]  = state_i[7:0];     // b15 (r=3, c=3)

    // Column 1 (Word 1: [95:64])  -> {s[0][1], s[1][2], s[2][3], s[3][0]} = {b4, b9, b14, b3}
    assign state_o[95:88]   = state_i[95:88];   // b4  (r=0, c=1)
    assign state_o[87:80]   = state_i[55:48];   // b9  (r=1, c=2)
    assign state_o[79:72]   = state_i[15:8];    // b14 (r=2, c=3)
    assign state_o[71:64]   = state_i[103:96];  // b3  (r=3, c=0)

    // Column 2 (Word 2: [63:32])  -> {s[0][2], s[1][3], s[2][0], s[3][1]} = {b8, b13, b2, b7}
    assign state_o[63:56]   = state_i[63:56];   // b8  (r=0, c=2)
    assign state_o[55:48]   = state_i[23:16];   // b13 (r=1, c=3)
    assign state_o[47:40]   = state_i[111:104]; // b2  (r=2, c=0)
    assign state_o[39:32]   = state_i[71:64];   // b7  (r=3, c=1)

    // Column 3 (Word 3: [31:0])   -> {s[0][3], s[1][0], s[2][1], s[3][2]} = {b12, b1, b6, b11}
    assign state_o[31:24]   = state_i[31:24];   // b12 (r=0, c=3)
    assign state_o[23:16]   = state_i[119:112]; // b1  (r=1, c=0)
    assign state_o[15:8]    = state_i[79:72];   // b6  (r=2, c=1)
    assign state_o[7:0]     = state_i[39:32];   // b11 (r=3, c=2)

endmodule

