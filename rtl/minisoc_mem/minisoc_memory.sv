// ==============================================================================
// Module: minisoc_memory
// Description: MiniSoC AES Shared Single-Port Synchronous SRAM & Arbitrator
//              (Block Guide Sec. 7 & LIM-MEM-01)
//              - Capacity: 1024 words x 32 bits (256 AES blocks of 128 bits).
//              - Word ordering per 128-bit AES block at base = 4 * blk_idx:
//                  base + 0 : block[127:96] (Word 0)
//                  base + 1 : block[95:64]  (Word 1)
//                  base + 2 : block[63:32]  (Word 2)
//                  base + 3 : block[31:0]   (Word 3)
//              - Ownership controlled by mem_sel_aes_i (SYSTEM_CONTROL.MEM_SEL_AES):
//                  0 -> External MEMORY DATA interface owns the SRAM port
//                  1 -> Internal AES Engine owns the SRAM port
//              - No functional reset on the memory array (Sec. 3 & Sec. 7.3).
// ==============================================================================

module minisoc_memory (
    // Ownership Select (0 = External MEMORY DATA, 1 = AES Engine)
    input  logic        mem_sel_aes_i,

    // External MEMORY DATA Interface (Sec. 3 & Sec. 7.3)
    input  logic        ext_clk_i,
    input  logic        ext_wr_en_i,
    input  logic [9:0]  ext_addr_i,
    input  logic [31:0] ext_wdata_i,
    output logic [31:0] ext_rdata_o,

    // Internal AES Engine Memory Interface (Sec. 7.2 & Sec. 8.3)
    input  logic        aes_clk_i,
    input  logic        aes_wr_en_i,
    input  logic [9:0]  aes_addr_i,
    input  logic [31:0] aes_wdata_i,
    output logic [31:0] aes_rdata_o
);

    // --------------------------------------------------------------------------
    // Single-Port Ownership Multiplexer (Sec. 7.2)
    // --------------------------------------------------------------------------
    logic        sram_clk;
    logic        sram_wr_en;
    logic [9:0]  sram_addr;
    logic [31:0] sram_wdata;
    logic [31:0] sram_rdata_q;

    assign sram_clk   = mem_sel_aes_i ? aes_clk_i   : ext_clk_i;
    assign sram_wr_en = mem_sel_aes_i ? aes_wr_en_i : ext_wr_en_i;
    assign sram_addr  = mem_sel_aes_i ? aes_addr_i  : ext_addr_i;
    assign sram_wdata = mem_sel_aes_i ? aes_wdata_i : ext_wdata_i;

    // --------------------------------------------------------------------------
    // Physical Single-Port Synchronous SRAM (1024 x 32 bits, no reset)
    // --------------------------------------------------------------------------
    logic [31:0] mem [0:1023];

    always_ff @(posedge sram_clk) begin
        if (sram_wr_en) begin
            mem[sram_addr] <= sram_wdata;
        end else begin
            sram_rdata_q <= mem[sram_addr];
        end
    end

    assign ext_rdata_o = sram_rdata_q;
    assign aes_rdata_o = sram_rdata_q;

endmodule
