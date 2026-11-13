// ==============================================================================
// Module: minisoc_aes_key_exp
// Description: AES-128 Pre-Computed Key Expansion Module (NIST FIPS-197, Sec 5.2)
//              Generates and stores all 11 round keys (128-bit each, K0..K10)
//              in 10 clock cycles upon start_i assertion.
//              Provides zero-latency combinational read access to any round key
//              via round_sel_i (supporting both forward K0->K10 encryption and
//              reverse K10->K0 decryption without re-expansion overhead).
// ==============================================================================

module minisoc_aes_key_exp (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         start_i,
    input  logic [127:0] key_i,
    input  logic [3:0]   round_sel_i,
    output logic [127:0] round_key_o,
    output logic         busy_o,
    output logic         done_o
);

    // --------------------------------------------------------------------------
    // Storage for 11 Round Keys (K0 .. K10)
    // --------------------------------------------------------------------------
    logic [127:0] round_keys_q [0:10];
    logic [3:0]   round_cnt_q;
    logic         busy_q;
    logic         done_q;

    // --------------------------------------------------------------------------
    // Combinational Key Schedule Datapath (1 Round Key per Cycle)
    // --------------------------------------------------------------------------
    logic [3:0]   prev_idx;
    logic [127:0] prev_key;
    logic [31:0]  w0, w1, w2, w3;
    logic [31:0]  rot_w3;
    logic [31:0]  sub_w3;
    logic [7:0]   rcon_byte;
    logic [31:0]  g_w3;
    logic [31:0]  w4, w5, w6, w7;
    logic [127:0] next_round_key;

    assign prev_idx = (round_cnt_q >= 4'd1 && round_cnt_q <= 4'd10) ? (round_cnt_q - 4'd1) : 4'd0;
    assign prev_key = round_keys_q[prev_idx];

    assign w0 = prev_key[127:96];
    assign w1 = prev_key[95:64];
    assign w2 = prev_key[63:32];
    assign w3 = prev_key[31:0];

    // RotWord(w3): cyclic left shift by 1 byte
    assign rot_w3 = {w3[23:0], w3[31:24]};

    // SubWord(RotWord(w3)): 4 parallel S-Box instances
    genvar b;
    generate
        for (b = 0; b < 4; b++) begin : gen_sub_word
            minisoc_aes_sbox u_sbox_key (
                .data_i (rot_w3[31 - 8*b -: 8]),
                .data_o (sub_w3[31 - 8*b -: 8])
            );
        end
    endgenerate

    // Rcon[r] lookup for AES-128 rounds 1..10 (FIPS-197 Table 5)
    always_comb begin
        unique case (round_cnt_q)
            4'd1:    rcon_byte = 8'h01;
            4'd2:    rcon_byte = 8'h02;
            4'd3:    rcon_byte = 8'h04;
            4'd4:    rcon_byte = 8'h08;
            4'd5:    rcon_byte = 8'h10;
            4'd6:    rcon_byte = 8'h20;
            4'd7:    rcon_byte = 8'h40;
            4'd8:    rcon_byte = 8'h80;
            4'd9:    rcon_byte = 8'h1b;
            4'd10:   rcon_byte = 8'h36;
            default: rcon_byte = 8'h00;
        endcase
    end

    assign g_w3 = sub_w3 ^ {rcon_byte, 24'h00_0000};

    assign w4 = w0 ^ g_w3;
    assign w5 = w1 ^ w4;
    assign w6 = w2 ^ w5;
    assign w7 = w3 ^ w6;

    assign next_round_key = {w4, w5, w6, w7};

    // --------------------------------------------------------------------------
    // Sequential Control & Round Key Array Update
    // --------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            for (int i = 0; i <= 10; i++) begin
                round_keys_q[i] <= 128'h0;
            end
            round_cnt_q <= 4'd0;
            busy_q      <= 1'b0;
            done_q      <= 1'b0;
        end else begin
            if (start_i && !busy_q) begin
                round_keys_q[0] <= key_i;
                round_cnt_q     <= 4'd1;
                busy_q          <= 1'b1;
                done_q          <= 1'b0;
            end else if (busy_q) begin
                round_keys_q[round_cnt_q] <= next_round_key;
                if (round_cnt_q == 4'd10) begin
                    round_cnt_q <= 4'd0;
                    busy_q      <= 1'b0;
                    done_q      <= 1'b1;
                end else begin
                    round_cnt_q <= round_cnt_q + 4'd1;
                end
            end else begin
                done_q <= 1'b0;
            end
        end
    end

    // --------------------------------------------------------------------------
    // Combinational Round Key Read Multiplexer
    // --------------------------------------------------------------------------
    assign round_key_o = (round_sel_i <= 4'd10) ? round_keys_q[round_sel_i] : 128'h0;
    assign busy_o      = busy_q;
    assign done_o      = done_q;

endmodule
