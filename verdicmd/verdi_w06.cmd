wvCreateWindow
verdiSetActWin -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_minisoc_aes_top"
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1_CTRL_CFG" \
{/tb_minisoc_aes_top/sys_clk} -height 16 \
{/tb_minisoc_aes_top/rst_n} -height 16 \
{/tb_minisoc_aes_top/mem_sel_aes} -height 16 \
{/tb_minisoc_aes_top/aes_start} -height 16 \
{/tb_minisoc_aes_top/cfg_mode\[2:0\]} -height 16 \
{/tb_minisoc_aes_top/cfg_decrypt} -height 16 \
{/tb_minisoc_aes_top/cfg_num_blocks\[31:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G2_AES_STATUS" \
{/tb_minisoc_aes_top/u_dut_aes/state_q\[3:0\]} -height 16 \
{/tb_minisoc_aes_top/u_dut_aes/blk_idx_q\[8:0\]} -height 16 \
{/tb_minisoc_aes_top/aes_busy} -height 16 \
{/tb_minisoc_aes_top/aes_done} -height 16 \
{/tb_minisoc_aes_top/aes_error} -height 16 \
{/tb_minisoc_aes_top/aes_blocks_done\[8:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G3_AES_BLOCKS" \
{/tb_minisoc_aes_top/u_dut_aes/rd_block_q\[127:0\]} -height 16 \
{/tb_minisoc_aes_top/u_dut_aes/dp_block_in\[127:0\]} -height 16 \
{/tb_minisoc_aes_top/u_dut_aes/dp_block_out\[127:0\]} -height 16 \
{/tb_minisoc_aes_top/u_dut_aes/wr_block_q\[127:0\]} -height 16 \
{/tb_minisoc_aes_top/u_dut_aes/chain_vec_q\[127:0\]} -height 16 \
{/tb_minisoc_aes_top/u_dut_aes/ctr_q\[63:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G4_SHARED_SRAM" \
{/tb_minisoc_aes_top/mem_clk} -height 16 \
{/tb_minisoc_aes_top/mem_i_wr_en} -height 16 \
{/tb_minisoc_aes_top/mem_i_addr\[9:0\]} -height 16 \
{/tb_minisoc_aes_top/mem_i_data\[31:0\]} -height 16 \
{/tb_minisoc_aes_top/mem_o_data\[31:0\]} -height 16 \
{/tb_minisoc_aes_top/aes_mem_wr_en} -height 16 \
{/tb_minisoc_aes_top/aes_mem_addr\[9:0\]} -height 16 \
{/tb_minisoc_aes_top/aes_mem_wdata\[31:0\]} -height 16 \
{/tb_minisoc_aes_top/aes_mem_rdata\[31:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G5_VERIF" \
{/tb_minisoc_aes_top/pass_cnt\[31:0\]} -height 16 \
{/tb_minisoc_aes_top/err_cnt\[31:0\]} -height 16 \
}
wvGetSignalClose -win $_nWave2
wvZoomAll -win $_nWave2
