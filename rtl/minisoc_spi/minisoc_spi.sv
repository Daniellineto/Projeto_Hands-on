// ==============================================================================
// Module: minisoc_spi
// Description: MiniSoC AES SPI Front-End & Register Bank (Block Guide Sec. 5 & 6)
//              - SPI Mode 0 (CPOL=0, CPHA=0): MOSI sampled on posedge spi_sclk_i,
//                MISO updated on negedge spi_sclk_i, MSB-first, up to 25 MHz.
//              - 40-bit frame format: {RWb[39], ADDR[38:33], RSV[32], DATA[31:0]}
//                * WRITE (RWb=0): single 40-bit transaction.
//                * READ  (RWb=1): two 40-bit transactions; 1st selects ADDR,
//                  2nd (NOP 0x3F) shifts out {8'h00, rd_data[31:0]} on MISO.
//              - Clock-Domain Crossing (Sec. 5.3): serial reception in spi_sclk_i
//                domain; complete frame captured statically and event transported
//                via toggle synchronizer (T-FF -> 2-FF sync + edge detect) to
//                always-on clk_i (2 GHz) register bank domain.
// ==============================================================================

module minisoc_spi #(
    parameter logic [31:0] VERSION_ID = 32'h0001_0000
) (
    // Always-on Control Domain (2 GHz reference clock)
    input  logic         clk_i,
    input  logic         rst_ni,

    // SPI External Interface (Mode 0, <= 25 MHz)
    input  logic         spi_sclk_i,
    input  logic         spi_cs_ni,
    input  logic         spi_mosi_i,
    output logic         spi_miso_o,

    // AES Configuration Outputs (clk_i domain)
    output logic [127:0] cfg_key_o,
    output logic [127:0] cfg_iv_o,
    output logic [63:0]  cfg_counter_o,
    output logic [31:0]  cfg_num_blocks_o,
    output logic [2:0]   cfg_mode_o,
    output logic         cfg_decrypt_o,
    output logic         aes_start_o,

    // AES Status Inputs
    input  logic         aes_busy_i,
    input  logic         aes_done_i,
    input  logic         aes_error_i,
    input  logic [8:0]   aes_blocks_done_i,

    // System / Memory / PLL Control & Status
    output logic         mem_sel_aes_o,
    output logic         pll_enable_o,
    output logic [1:0]   pll_div_sel_o,
    input  logic         pll_locked_i
);

    // --------------------------------------------------------------------------
    // Register Address Map (Block Guide Sec. 6)
    // --------------------------------------------------------------------------
    localparam logic [5:0] ADDR_KEY0           = 6'h00;
    localparam logic [5:0] ADDR_KEY1           = 6'h01;
    localparam logic [5:0] ADDR_KEY2           = 6'h02;
    localparam logic [5:0] ADDR_KEY3           = 6'h03;
    localparam logic [5:0] ADDR_IV0            = 6'h04;
    localparam logic [5:0] ADDR_IV1            = 6'h05;
    localparam logic [5:0] ADDR_IV2            = 6'h06;
    localparam logic [5:0] ADDR_IV3            = 6'h07;
    localparam logic [5:0] ADDR_COUNTER_HI     = 6'h08;
    localparam logic [5:0] ADDR_COUNTER_LO     = 6'h09;
    localparam logic [5:0] ADDR_NUM_BLOCKS     = 6'h0A;
    localparam logic [5:0] ADDR_AES_CONTROL    = 6'h0B;
    localparam logic [5:0] ADDR_AES_STATUS     = 6'h0C;
    localparam logic [5:0] ADDR_VERSION        = 6'h0D;
    localparam logic [5:0] ADDR_SYSTEM_CONTROL = 6'h0E;
    localparam logic [5:0] ADDR_SYSTEM_STATUS  = 6'h0F;
    localparam logic [5:0] ADDR_NOP            = 6'h3F;

    // --------------------------------------------------------------------------
    // SPI Domain Reset Control
    // - Bit counters and shift registers reset when global rst_ni=0 or CS=1.
    // - Captured frame & toggle FF reset ONLY on global rst_ni=0 so that
    //   deasserting spi_cs_ni after bit 39 never erases the CDC event.
    // --------------------------------------------------------------------------
    logic spi_frame_rst_n;
    assign spi_frame_rst_n = rst_ni & ~spi_cs_ni;

    // --------------------------------------------------------------------------
    // SPI RX Path (posedge spi_sclk_i, MSB-first, 40-bit frame)
    // --------------------------------------------------------------------------
    logic [38:0] rx_shift_q;
    logic [5:0]  rx_bit_cnt_q;
    logic [39:0] rx_frame_captured_q;
    logic        rx_toggle_q;

    always_ff @(posedge spi_sclk_i or negedge spi_frame_rst_n) begin
        if (!spi_frame_rst_n) begin
            rx_shift_q   <= 39'd0;
            rx_bit_cnt_q <= 6'd0;
        end else begin
            if (rx_bit_cnt_q == 6'd39) begin
                rx_shift_q   <= 39'd0;
                rx_bit_cnt_q <= 6'd0;
            end else begin
                rx_shift_q   <= {rx_shift_q[37:0], spi_mosi_i};
                rx_bit_cnt_q <= rx_bit_cnt_q + 6'd1;
            end
        end
    end

    always_ff @(posedge spi_sclk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rx_frame_captured_q <= 40'd0;
            rx_toggle_q         <= 1'b0;
        end else if (!spi_cs_ni && (rx_bit_cnt_q == 6'd39)) begin
            rx_frame_captured_q <= {rx_shift_q, spi_mosi_i};
            rx_toggle_q         <= ~rx_toggle_q;
        end
    end

    // --------------------------------------------------------------------------
    // CDC: Toggle Synchronizer (spi_sclk_i -> clk_i)
    // 2-FF synchronizer (ff1, ff2) + 1-FF edge detector (ff3)
    // --------------------------------------------------------------------------
    logic toggle_sync_ff1_q;
    logic toggle_sync_ff2_q;
    logic toggle_sync_ff3_q;
    logic frame_valid_clk;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            toggle_sync_ff1_q <= 1'b0;
            toggle_sync_ff2_q <= 1'b0;
            toggle_sync_ff3_q <= 1'b0;
        end else begin
            toggle_sync_ff1_q <= rx_toggle_q;
            toggle_sync_ff2_q <= toggle_sync_ff1_q;
            toggle_sync_ff3_q <= toggle_sync_ff2_q;
        end
    end

    assign frame_valid_clk = toggle_sync_ff2_q ^ toggle_sync_ff3_q;

    // Decoded fields from static captured frame (stable for >= 3200 clk cycles)
    logic        frame_rwb;
    logic [5:0]  frame_addr;
    logic [31:0] frame_data;

    assign frame_rwb  = rx_frame_captured_q[39];
    assign frame_addr = rx_frame_captured_q[38:33];
    assign frame_data = rx_frame_captured_q[31:0];

    // --------------------------------------------------------------------------
    // Register Bank (Always-On clk_i Domain)
    // --------------------------------------------------------------------------
    logic [31:0] key0_q, key1_q, key2_q, key3_q;
    logic [31:0] iv0_q,  iv1_q,  iv2_q,  iv3_q;
    logic [31:0] counter_hi_q, counter_lo_q;
    logic [31:0] num_blocks_q;

    // AES_CONTROL fields
    logic [2:0]  aes_mode_q;
    logic        aes_decrypt_q;
    logic        aes_start_q;

    // SYSTEM_CONTROL fields
    logic        mem_sel_aes_q;
    logic        pll_enable_q;
    logic [1:0]  pll_div_sel_q;

    // Latched read data for 2nd SPI transaction (NOP return phase)
    logic [31:0] rd_data_clk_q;
    logic [31:0] rd_mux_data;

    // Read Multiplexer
    always_comb begin
        case (frame_addr)
            ADDR_KEY0:           rd_mux_data = key0_q;
            ADDR_KEY1:           rd_mux_data = key1_q;
            ADDR_KEY2:           rd_mux_data = key2_q;
            ADDR_KEY3:           rd_mux_data = key3_q;
            ADDR_IV0:            rd_mux_data = iv0_q;
            ADDR_IV1:            rd_mux_data = iv1_q;
            ADDR_IV2:            rd_mux_data = iv2_q;
            ADDR_IV3:            rd_mux_data = iv3_q;
            ADDR_COUNTER_HI:     rd_mux_data = counter_hi_q;
            ADDR_COUNTER_LO:     rd_mux_data = counter_lo_q;
            ADDR_NUM_BLOCKS:     rd_mux_data = num_blocks_q;
            ADDR_AES_CONTROL:    rd_mux_data = {27'd0, aes_mode_q, aes_decrypt_q, 1'b0};
            ADDR_AES_STATUS:     rd_mux_data = {20'd0, aes_blocks_done_i, aes_error_i, aes_done_i, aes_busy_i};
            ADDR_VERSION:        rd_mux_data = VERSION_ID;
            ADDR_SYSTEM_CONTROL: rd_mux_data = {28'd0, pll_div_sel_q, pll_enable_q, mem_sel_aes_q};
            ADDR_SYSTEM_STATUS:  rd_mux_data = {31'd0, pll_locked_i};
            default:             rd_mux_data = 32'h0000_0000;
        endcase
    end

    // Sequential Register Updates
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            key0_q        <= 32'd0;
            key1_q        <= 32'd0;
            key2_q        <= 32'd0;
            key3_q        <= 32'd0;
            iv0_q         <= 32'd0;
            iv1_q         <= 32'd0;
            iv2_q         <= 32'd0;
            iv3_q         <= 32'd0;
            counter_hi_q  <= 32'd0;
            counter_lo_q  <= 32'd0;
            num_blocks_q  <= 32'd0;
            aes_mode_q    <= 3'd0;
            aes_decrypt_q <= 1'b0;
            aes_start_q   <= 1'b0;
            mem_sel_aes_q <= 1'b0;
            pll_enable_q  <= 1'b0;
            pll_div_sel_q <= 2'd0;
            rd_data_clk_q <= 32'd0;
        end else begin
            // START is write-one-pulse: self-clears every clk_i cycle
            aes_start_q <= 1'b0;

            if (frame_valid_clk) begin
                if (!frame_rwb) begin
                    // WRITE transaction (RWb = 0)
                    // Read-only (0x0C, 0x0D, 0x0F), NOP (0x3F), and unmapped
                    // addresses are ignored.
                    case (frame_addr)
                        ADDR_KEY0:       key0_q       <= frame_data;
                        ADDR_KEY1:       key1_q       <= frame_data;
                        ADDR_KEY2:       key2_q       <= frame_data;
                        ADDR_KEY3:       key3_q       <= frame_data;
                        ADDR_IV0:        iv0_q        <= frame_data;
                        ADDR_IV1:        iv1_q        <= frame_data;
                        ADDR_IV2:        iv2_q        <= frame_data;
                        ADDR_IV3:        iv3_q        <= frame_data;
                        ADDR_COUNTER_HI: counter_hi_q <= frame_data;
                        ADDR_COUNTER_LO: counter_lo_q <= frame_data;
                        ADDR_NUM_BLOCKS: num_blocks_q <= frame_data;
                        ADDR_AES_CONTROL: begin
                            aes_mode_q    <= frame_data[4:2];
                            aes_decrypt_q <= frame_data[1];
                            aes_start_q   <= frame_data[0];
                        end
                        ADDR_SYSTEM_CONTROL: begin
                            mem_sel_aes_q <= frame_data[0];
                            pll_enable_q  <= frame_data[1];
                            pll_div_sel_q <= frame_data[3:2];
                        end
                        default: begin
                            // No write action for R-only, NOP, or unmapped addresses
                        end
                    endcase
                end else begin
                    // READ request transaction (RWb = 1)
                    // NOP (0x3F) preserves previously latched read data
                    if (frame_addr != ADDR_NOP) begin
                        rd_data_clk_q <= rd_mux_data;
                    end
                end
            end
        end
    end

    // --------------------------------------------------------------------------
    // SPI TX Path (negedge spi_sclk_i, Mode 0, MSB-first)
    // Shifts out 40-bit response {8'h00, rd_data_clk_q[31:0]}:
    // - Bits [39:32] (header phase, clocks 1..8): 8'h00
    // - On 8th falling edge (tx_bit_cnt_q == 7): loads rd_data_clk_q[31:0]
    // - Bits [31:0]  (data phase, clocks 9..40): rd_data_clk_q[31] down to [0]
    // --------------------------------------------------------------------------
    logic [31:0] tx_shift_q;
    logic [5:0]  tx_bit_cnt_q;
    logic        spi_miso_q;

    always_ff @(negedge spi_sclk_i or negedge spi_frame_rst_n) begin
        if (!spi_frame_rst_n) begin
            tx_shift_q   <= 32'd0;
            tx_bit_cnt_q <= 6'd0;
            spi_miso_q   <= 1'b0;
        end else begin
            if (tx_bit_cnt_q < 6'd7) begin
                spi_miso_q   <= 1'b0;
                tx_bit_cnt_q <= tx_bit_cnt_q + 6'd1;
            end else if (tx_bit_cnt_q == 6'd7) begin
                // 8th falling edge: present MSB (bit 31) for 9th rising edge
                spi_miso_q   <= rd_data_clk_q[31];
                tx_shift_q   <= {rd_data_clk_q[30:0], 1'b0};
                tx_bit_cnt_q <= 6'd8;
            end else if (tx_bit_cnt_q < 6'd39) begin
                // 9th..39th falling edges: present bits 30..0 for 10th..40th rising edges
                spi_miso_q   <= tx_shift_q[31];
                tx_shift_q   <= {tx_shift_q[30:0], 1'b0};
                tx_bit_cnt_q <= tx_bit_cnt_q + 6'd1;
            end else begin
                // 40th falling edge: end of 40-bit frame
                spi_miso_q   <= 1'b0;
                tx_shift_q   <= 32'd0;
                tx_bit_cnt_q <= 6'd0;
            end
        end
    end

    // --------------------------------------------------------------------------
    // Output Assignments
    // --------------------------------------------------------------------------
    assign spi_miso_o       = spi_miso_q;
    assign cfg_key_o        = {key0_q, key1_q, key2_q, key3_q};
    assign cfg_iv_o         = {iv0_q,  iv1_q,  iv2_q,  iv3_q};
    assign cfg_counter_o    = {counter_hi_q, counter_lo_q};
    assign cfg_num_blocks_o = num_blocks_q;
    assign cfg_mode_o       = aes_mode_q;
    assign cfg_decrypt_o    = aes_decrypt_q;
    assign aes_start_o      = aes_start_q;
    assign mem_sel_aes_o    = mem_sel_aes_q;
    assign pll_enable_o     = pll_enable_q;
    assign pll_div_sel_o    = pll_div_sel_q;

endmodule
