wvCreateWindow
verdiSetActWin -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_minisoc_spi_pll"
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1_SPI_BUS" \
{/tb_minisoc_spi_pll/clk} -height 16 \
{/tb_minisoc_spi_pll/rst_n} -height 16 \
{/tb_minisoc_spi_pll/spi_cs_n} -height 16 \
{/tb_minisoc_spi_pll/spi_sclk} -height 16 \
{/tb_minisoc_spi_pll/spi_mosi} -height 16 \
{/tb_minisoc_spi_pll/spi_miso} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G2_SPI_CDC" \
{/tb_minisoc_spi_pll/u_dut_spi/rx_bit_cnt_q\[5:0\]} -height 16 \
{/tb_minisoc_spi_pll/u_dut_spi/rx_frame_captured_q\[39:0\]} -height 16 \
{/tb_minisoc_spi_pll/u_dut_spi/rx_toggle_q} -height 16 \
{/tb_minisoc_spi_pll/u_dut_spi/frame_valid_clk} -height 16 \
{/tb_minisoc_spi_pll/u_dut_spi/rd_data_clk_q\[31:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G3_REG_BANK" \
{/tb_minisoc_spi_pll/cfg_key\[127:0\]} -height 16 \
{/tb_minisoc_spi_pll/cfg_iv\[127:0\]} -height 16 \
{/tb_minisoc_spi_pll/cfg_counter\[63:0\]} -height 16 \
{/tb_minisoc_spi_pll/cfg_num_blocks\[31:0\]} -height 16 \
{/tb_minisoc_spi_pll/cfg_mode\[2:0\]} -height 16 \
{/tb_minisoc_spi_pll/cfg_decrypt} -height 16 \
{/tb_minisoc_spi_pll/aes_start} -height 16 \
{/tb_minisoc_spi_pll/mem_sel_aes} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G4_PLL_MOCK" \
{/tb_minisoc_spi_pll/pll_enable} -height 16 \
{/tb_minisoc_spi_pll/pll_div_sel\[1:0\]} -height 16 \
{/tb_minisoc_spi_pll/pll_locked} -height 16 \
{/tb_minisoc_spi_pll/sys_clk} -height 16 \
{/tb_minisoc_spi_pll/u_dut_pll/lock_cnt_q\[7:0\]} -height 16 \
{/tb_minisoc_spi_pll/u_dut_pll/lock_target_q\[7:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G5_STATUS" \
{/tb_minisoc_spi_pll/pass_cnt\[31:0\]} -height 16 \
{/tb_minisoc_spi_pll/err_cnt\[31:0\]} -height 16 \
{/tb_minisoc_spi_pll/sys_clk_glitch_cnt\[31:0\]} -height 16 \
}
wvGetSignalClose -win $_nWave2
wvZoomAll -win $_nWave2
