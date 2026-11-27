// ==============================================================================
// Module: minisoc_aes_top
// Description: MiniSoC AES-128 Multi-Block Engine & Memory Controller
//              (Block Guide Sec. 8)
//              - On valid start_i: captures KEY, IV, COUNTER, MODE, DECRYPT,
//                and NUM_BLOCKS.
//              - Validates configuration:
//                  * NUM_BLOCKS in 1..256
//                  * MODE in implemented v1.0 set:
//                      - 3'b000 : ECB (Cipher / Inverse Cipher)
//                      - 3'b001 : CBC (Cipher / Inverse Cipher with IV chaining)
//                      - 3'b101 : CTR (Cipher on IV ^ {64'h0, COUNTER}, counter++)
//                  * Out-of-range NUM_BLOCKS or reserved/unimplemented MODE
//                    asserts error_o = 1, busy_o = 0 and terminates without
//                    memory modification.
//              - For each block (0 .. NUM_BLOCKS-1):
//                  1. Pre-computes all 11 round keys once per batch (10 cycles).
//                  2. Reads 4 x 32-bit words from shared SRAM at base = 4*blk_idx.
//                  3. Processes the 128-bit block through minisoc_aes_dp (10 cycles).
//                  4. Writes 4 x 32-bit words back in-place to base = 4*blk_idx.
//                  5. Increments blocks_done_o; upon batch completion asserts
//                     sticky done_o = 1 until the next valid start_i is accepted.
// ==============================================================================

module minisoc_aes_top (
    input  logic         clk_i,
    input  logic         rst_ni,

    // Control & Configuration from SPI Register Bank
    input  logic         start_i,
    input  logic         cfg_decrypt_i,
    input  logic [2:0]   cfg_mode_i,
    input  logic [31:0]  cfg_num_blocks_i,
    input  logic [127:0] cfg_key_i,
    input  logic [127:0] cfg_iv_i,
    input  logic [63:0]  cfg_counter_i,

    // Status Outputs to SPI Register Bank (AES_STATUS)
    output logic         busy_o,
    output logic         done_o,
    output logic         error_o,
    output logic [8:0]   blocks_done_o,

    // Shared Memory Master Interface (active when MEM_SEL_AES = 1)
    output logic         mem_wr_en_o,
    output logic [9:0]   mem_addr_o,
    output logic [31:0]  mem_wdata_o,
    input  logic [31:0]  mem_rdata_i
);

    // --------------------------------------------------------------------------
    // Mode Encodings (Block Guide Sec. 8.2)
    // Note: PCBC (3'b010), CFB (3'b011), and OFB (3'b100) are deferred to Week 10.
    // --------------------------------------------------------------------------
    localparam logic [2:0] MODE_ECB = 3'b000;
    localparam logic [2:0] MODE_CBC = 3'b001;
    localparam logic [2:0] MODE_CTR = 3'b101;

    // --------------------------------------------------------------------------
    // Controller FSM States
    // --------------------------------------------------------------------------
    typedef enum logic [3:0] {
        ST_IDLE       = 4'd0,
        ST_VALIDATE   = 4'd1,
        ST_KEY_EXP    = 4'd2,
        ST_RD_W0      = 4'd3,
        ST_RD_W1      = 4'd4,
        ST_RD_W2      = 4'd5,
        ST_RD_W3      = 4'd6,
        ST_RD_WAIT    = 4'd7,
        ST_DP_START   = 4'd8,
        ST_PROCESS_DP = 4'd9,
        ST_WR_W0      = 4'd10,
        ST_WR_W1      = 4'd11,
        ST_WR_W2      = 4'd12,
        ST_WR_W3      = 4'd13,
        ST_CHECK_NEXT = 4'd14,
        ST_FINISH     = 4'd15
    } aes_fsm_e;

    aes_fsm_e state_q;

    // --------------------------------------------------------------------------
    // Captured Configuration & Processing Registers
    // --------------------------------------------------------------------------
    logic [127:0] key_q;
    logic [127:0] iv_q;
    logic [127:0] chain_vec_q;
    logic [63:0]  ctr_q;
    logic [31:0]  num_blocks_q;
    logic [2:0]   mode_q;
    logic         decrypt_q;

    logic [8:0]   blk_idx_q;
    logic [8:0]   blocks_done_q;
    logic [127:0] rd_block_q;
    logic [127:0] wr_block_q;

    logic         busy_q;
    logic         done_q;
    logic         error_q;

    // --------------------------------------------------------------------------
    // Configuration Validation (Sec. 8.2)
    // --------------------------------------------------------------------------
    logic num_blocks_valid;
    logic mode_valid;
    logic cfg_valid;

    assign num_blocks_valid = (num_blocks_q >= 32'd1) && (num_blocks_q <= 32'd256);
    assign mode_valid       = (mode_q == MODE_ECB) || (mode_q == MODE_CBC) || (mode_q == MODE_CTR);
    assign cfg_valid        = num_blocks_valid && mode_valid;

    // --------------------------------------------------------------------------
    // Submodule Interconnects: Key Expansion & AES-128 Datapath
    // --------------------------------------------------------------------------
    logic         key_exp_start;
    logic [3:0]   dp_round_sel;
    logic [127:0] round_key_bus;
    logic         key_exp_busy;
    logic         key_exp_done;

    logic         dp_start;
    logic         dp_decrypt;
    logic [127:0] dp_block_in;
    logic [127:0] dp_block_out;
    logic         dp_busy;
    logic         dp_done;

    assign key_exp_start = (state_q == ST_VALIDATE) && cfg_valid;
    assign dp_start      = (state_q == ST_DP_START);

    // Mode-dependent Datapath Input & Direction Selection
    // - ECB: direct block in; direction = decrypt_q
    // - CBC: Encrypt XORs input with chain_vec_q; Decrypt passes ciphertext directly
    // - CTR: always Encrypt (dp_decrypt = 0) on (iv_q ^ {64'd0, ctr_q})
    always_comb begin
        case (mode_q)
            MODE_ECB: begin
                dp_decrypt  = decrypt_q;
                dp_block_in = rd_block_q;
            end
            MODE_CBC: begin
                dp_decrypt  = decrypt_q;
                dp_block_in = decrypt_q ? rd_block_q : (rd_block_q ^ chain_vec_q);
            end
            MODE_CTR: begin
                dp_decrypt  = 1'b0;
                dp_block_in = iv_q ^ {64'd0, ctr_q};
            end
            default: begin
                dp_decrypt  = 1'b0;
                dp_block_in = 128'd0;
            end
        endcase
    end

    minisoc_aes_key_exp u_key_exp (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .start_i     (key_exp_start),
        .key_i       (key_q),
        .round_sel_i (dp_round_sel),
        .round_key_o (round_key_bus),
        .busy_o      (key_exp_busy),
        .done_o      (key_exp_done)
    );

    minisoc_aes_dp u_dp (
        .clk_i       (clk_i),
        .rst_ni      (rst_ni),
        .start_i     (dp_start),
        .decrypt_i   (dp_decrypt),
        .block_i     (dp_block_in),
        .round_sel_o (dp_round_sel),
        .round_key_i (round_key_bus),
        .block_o     (dp_block_out),
        .busy_o      (dp_busy),
        .done_o      (dp_done)
    );

    // --------------------------------------------------------------------------
    // Shared Memory Address & Write Bus Generation (4 words per 128-bit block)
    // --------------------------------------------------------------------------
    logic [9:0] blk_base_addr;
    assign blk_base_addr = {blk_idx_q[7:0], 2'b00};

    always_comb begin
        mem_wr_en_o = 1'b0;
        mem_addr_o  = blk_base_addr;
        mem_wdata_o = 32'd0;

        case (state_q)
            ST_RD_W0: begin
                mem_wr_en_o = 1'b0;
                mem_addr_o  = blk_base_addr + 10'd0;
            end
            ST_RD_W1: begin
                mem_wr_en_o = 1'b0;
                mem_addr_o  = blk_base_addr + 10'd1;
            end
            ST_RD_W2: begin
                mem_wr_en_o = 1'b0;
                mem_addr_o  = blk_base_addr + 10'd2;
            end
            ST_RD_W3,
            ST_RD_WAIT: begin
                mem_wr_en_o = 1'b0;
                mem_addr_o  = blk_base_addr + 10'd3;
            end
            ST_WR_W0: begin
                mem_wr_en_o = 1'b1;
                mem_addr_o  = blk_base_addr + 10'd0;
                mem_wdata_o = wr_block_q[127:96];
            end
            ST_WR_W1: begin
                mem_wr_en_o = 1'b1;
                mem_addr_o  = blk_base_addr + 10'd1;
                mem_wdata_o = wr_block_q[95:64];
            end
            ST_WR_W2: begin
                mem_wr_en_o = 1'b1;
                mem_addr_o  = blk_base_addr + 10'd2;
                mem_wdata_o = wr_block_q[63:32];
            end
            ST_WR_W3: begin
                mem_wr_en_o = 1'b1;
                mem_addr_o  = blk_base_addr + 10'd3;
                mem_wdata_o = wr_block_q[31:0];
            end
            default: begin
                mem_wr_en_o = 1'b0;
                mem_addr_o  = 10'd0;
                mem_wdata_o = 32'd0;
            end
        endcase
    end

    // --------------------------------------------------------------------------
    // Main Sequential FSM
    // --------------------------------------------------------------------------
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q       <= ST_IDLE;
            key_q         <= 128'd0;
            iv_q          <= 128'd0;
            chain_vec_q   <= 128'd0;
            ctr_q         <= 64'd0;
            num_blocks_q  <= 32'd0;
            mode_q        <= 3'd0;
            decrypt_q     <= 1'b0;
            blk_idx_q     <= 9'd0;
            blocks_done_q <= 9'd0;
            rd_block_q    <= 128'd0;
            wr_block_q    <= 128'd0;
            busy_q        <= 1'b0;
            done_q        <= 1'b0;
            error_q       <= 1'b0;
        end else begin
            case (state_q)
                ST_IDLE: begin
                    if (start_i) begin
                        key_q        <= cfg_key_i;
                        iv_q         <= cfg_iv_i;
                        ctr_q        <= cfg_counter_i;
                        num_blocks_q <= cfg_num_blocks_i;
                        mode_q       <= cfg_mode_i;
                        decrypt_q    <= cfg_decrypt_i;
                        busy_q       <= 1'b1;
                        error_q      <= 1'b0;
                        state_q      <= ST_VALIDATE;
                    end
                end

                ST_VALIDATE: begin
                    if (cfg_valid) begin
                        // Valid START accepted: clear sticky DONE and reset block counters
                        done_q        <= 1'b0;
                        error_q       <= 1'b0;
                        blk_idx_q     <= 9'd0;
                        blocks_done_q <= 9'd0;
                        chain_vec_q   <= iv_q;
                        state_q       <= ST_KEY_EXP;
                    end else begin
                        // Invalid configuration: assert ERROR and abort without processing
                        busy_q        <= 1'b0;
                        done_q        <= 1'b0;
                        error_q       <= 1'b1;
                        blocks_done_q <= 9'd0;
                        state_q       <= ST_IDLE;
                    end
                end

                ST_KEY_EXP: begin
                    if (key_exp_done && !key_exp_busy) begin
                        state_q <= ST_RD_W0;
                    end
                end

                // 4-word synchronous SRAM burst read (1-cycle read latency)
                ST_RD_W0: begin
                    state_q <= ST_RD_W1;
                end

                ST_RD_W1: begin
                    rd_block_q[127:96] <= mem_rdata_i;
                    state_q            <= ST_RD_W2;
                end

                ST_RD_W2: begin
                    rd_block_q[95:64] <= mem_rdata_i;
                    state_q           <= ST_RD_W3;
                end

                ST_RD_W3: begin
                    rd_block_q[63:32] <= mem_rdata_i;
                    state_q           <= ST_RD_WAIT;
                end

                ST_RD_WAIT: begin
                    rd_block_q[31:0] <= mem_rdata_i;
                    state_q          <= ST_DP_START;
                end

                ST_DP_START: begin
                    state_q <= ST_PROCESS_DP;
                end

                ST_PROCESS_DP: begin
                    if (dp_done && !dp_busy) begin
                        case (mode_q)
                            MODE_ECB: begin
                                wr_block_q <= dp_block_out;
                            end
                            MODE_CBC: begin
                                if (!decrypt_q) begin
                                    wr_block_q  <= dp_block_out;
                                    chain_vec_q <= dp_block_out;
                                end else begin
                                    wr_block_q  <= dp_block_out ^ chain_vec_q;
                                    chain_vec_q <= rd_block_q;
                                end
                            end
                            MODE_CTR: begin
                                wr_block_q <= rd_block_q ^ dp_block_out;
                                ctr_q      <= ctr_q + 64'd1;
                            end
                            default: begin
                                wr_block_q <= dp_block_out;
                            end
                        endcase
                        state_q <= ST_WR_W0;
                    end
                end

                // 4-word synchronous SRAM burst write (in-place)
                ST_WR_W0: begin
                    state_q <= ST_WR_W1;
                end

                ST_WR_W1: begin
                    state_q <= ST_WR_W2;
                end

                ST_WR_W2: begin
                    state_q <= ST_WR_W3;
                end

                ST_WR_W3: begin
                    state_q <= ST_CHECK_NEXT;
                end

                ST_CHECK_NEXT: begin
                    blocks_done_q <= blocks_done_q + 9'd1;
                    if ((blk_idx_q + 9'd1) < num_blocks_q[8:0]) begin
                        blk_idx_q <= blk_idx_q + 9'd1;
                        state_q   <= ST_RD_W0;
                    end else begin
                        state_q <= ST_FINISH;
                    end
                end

                ST_FINISH: begin
                    busy_q  <= 1'b0;
                    done_q  <= 1'b1;
                    state_q <= ST_IDLE;
                end

                default: begin
                    state_q <= ST_IDLE;
                end
            endcase
        end
    end

    // --------------------------------------------------------------------------
    // Status Output Assignments
    // --------------------------------------------------------------------------
    assign busy_o        = busy_q;
    assign done_o        = done_q;
    assign error_o       = error_q;
    assign blocks_done_o = blocks_done_q;

endmodule
