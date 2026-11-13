// ==============================================================================
// Module: minisoc_aes_dp
// Description: AES-128 Iterative 128-bit Datapath (1 Round per Clock Cycle)
//              Supports both Cipher (decrypt_i = 0, NIST FIPS-197 Sec 5.1) and
//              Inverse Cipher (decrypt_i = 1, NIST FIPS-197 Sec 5.3).
//              Executes Initial AddRoundKey on start_i and completes Rounds 1..10
//              in 10 clock cycles, asserting done_o upon completion.
// ==============================================================================

module minisoc_aes_dp (
    input  logic         clk_i,
    input  logic         rst_ni,
    input  logic         start_i,
    input  logic         decrypt_i,
    input  logic [127:0] block_i,
    output logic [3:0]   round_sel_o,
    input  logic [127:0] round_key_i,
    output logic [127:0] block_o,
    output logic         busy_o,
    output logic         done_o
);

    // --------------------------------------------------------------------------
    // Datapath State & Control Registers
    // --------------------------------------------------------------------------
    logic [127:0] state_q;
    logic [3:0]   round_q;
    logic         decrypt_q;
    logic         busy_q;
    logic         done_q;

    // --------------------------------------------------------------------------
    // Round Key Index Selection (0..10)
    // - On start (idle): K0 for Encrypt (decrypt_i=0), K10 for Decrypt (decrypt_i=1)
    // - During rounds 1..10: K[round_q] for Encrypt, K[10 - round_q] for Decrypt
    // --------------------------------------------------------------------------
    always_comb begin
        if (!busy_q) begin
            round_sel_o = decrypt_i ? 4'd10 : 4'd0;
        end else begin
            round_sel_o = decrypt_q ? (4'd10 - round_q) : round_q;
        end
    end

    // --------------------------------------------------------------------------
    // Initial Round 0 AddRoundKey (block_i ^ K0 or K10)
    // --------------------------------------------------------------------------
    logic [127:0] init_ark_out;

    minisoc_aes_add_round_key u_init_ark (
        .state_i     (block_i),
        .round_key_i (round_key_i),
        .state_o     (init_ark_out)
    );

    // --------------------------------------------------------------------------
    // Forward Cipher Round Path (SubBytes -> ShiftRows -> [MixColumns] -> AddRoundKey)
    // --------------------------------------------------------------------------
    logic [127:0] fwd_sub_bytes;
    logic [127:0] fwd_shift_rows;
    logic [127:0] fwd_mix_columns;
    logic [127:0] fwd_ark_in;
    logic [127:0] fwd_next_state;

    minisoc_aes_sub_bytes u_sub_bytes (
        .state_i (state_q),
        .state_o (fwd_sub_bytes)
    );

    minisoc_aes_shift_rows u_shift_rows (
        .state_i (fwd_sub_bytes),
        .state_o (fwd_shift_rows)
    );

    minisoc_aes_mix_columns u_mix_columns (
        .state_i (fwd_shift_rows),
        .state_o (fwd_mix_columns)
    );

    // Bypass MixColumns in Final Round 10
    assign fwd_ark_in = (round_q == 4'd10) ? fwd_shift_rows : fwd_mix_columns;

    minisoc_aes_add_round_key u_fwd_ark (
        .state_i     (fwd_ark_in),
        .round_key_i (round_key_i),
        .state_o     (fwd_next_state)
    );

    // --------------------------------------------------------------------------
    // Inverse Cipher Round Path (InvShiftRows -> InvSubBytes -> AddRoundKey -> [InvMixColumns])
    // --------------------------------------------------------------------------
    logic [127:0] inv_shift_rows;
    logic [127:0] inv_sub_bytes;
    logic [127:0] inv_after_ark;
    logic [127:0] inv_mix_columns;
    logic [127:0] inv_next_state;

    minisoc_aes_inv_shift_rows u_inv_shift_rows (
        .state_i (state_q),
        .state_o (inv_shift_rows)
    );

    minisoc_aes_inv_sub_bytes u_inv_sub_bytes (
        .state_i (inv_shift_rows),
        .state_o (inv_sub_bytes)
    );

    minisoc_aes_add_round_key u_inv_ark (
        .state_i     (inv_sub_bytes),
        .round_key_i (round_key_i),
        .state_o     (inv_after_ark)
    );

    minisoc_aes_inv_mix_columns u_inv_mix_columns (
        .state_i (inv_after_ark),
        .state_o (inv_mix_columns)
    );

    // Bypass InvMixColumns in Final Round 10
    assign inv_next_state = (round_q == 4'd10) ? inv_after_ark : inv_mix_columns;

    // --------------------------------------------------------------------------
    // Sequential State & Round Counter Control
    // --------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q   <= 128'h0;
            round_q   <= 4'd0;
            decrypt_q <= 1'b0;
            busy_q    <= 1'b0;
            done_q    <= 1'b0;
        end else begin
            if (start_i && !busy_q) begin
                state_q   <= init_ark_out;
                round_q   <= 4'd1;
                decrypt_q <= decrypt_i;
                busy_q    <= 1'b1;
                done_q    <= 1'b0;
            end else if (busy_q) begin
                state_q <= decrypt_q ? inv_next_state : fwd_next_state;
                if (round_q == 4'd10) begin
                    round_q <= 4'd0;
                    busy_q  <= 1'b0;
                    done_q  <= 1'b1;
                end else begin
                    round_q <= round_q + 4'd1;
                end
            end else begin
                done_q <= 1'b0;
            end
        end
    end

    assign block_o = state_q;
    assign busy_o  = busy_q;
    assign done_o  = done_q;

endmodule

