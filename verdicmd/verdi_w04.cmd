wvCreateWindow
verdiSetActWin -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_minisoc_aes_dp"
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1_KEY_EXPANSION" \
{/tb_minisoc_aes_dp/clk} -height 16 \
{/tb_minisoc_aes_dp/rst_n} -height 16 \
{/tb_minisoc_aes_dp/key_exp_start} -height 16 \
{/tb_minisoc_aes_dp/key_in\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_key_exp/round_cnt_q\[3:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_key_exp/next_round_key\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/key_exp_busy} -height 16 \
{/tb_minisoc_aes_dp/key_exp_done} -height 16 \
{/tb_minisoc_aes_dp/key_round_sel\[3:0\]} -height 16 \
{/tb_minisoc_aes_dp/round_key_bus\[127:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G2_AES_DATAPATH" \
{/tb_minisoc_aes_dp/dp_start} -height 16 \
{/tb_minisoc_aes_dp/dp_decrypt} -height 16 \
{/tb_minisoc_aes_dp/dp_block_in\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/round_q\[3:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/state_q\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/dp_block_out\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/dp_busy} -height 16 \
{/tb_minisoc_aes_dp/dp_done} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G3_DP_ROUND_INTERNAL" \
{/tb_minisoc_aes_dp/u_dut_dp/fwd_sub_bytes\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/fwd_shift_rows\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/fwd_mix_columns\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/fwd_next_state\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/inv_shift_rows\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/inv_sub_bytes\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/inv_after_ark\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/inv_mix_columns\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/pass_cnt\[31:0\]} -height 16 \
{/tb_minisoc_aes_dp/err_cnt\[31:0\]} -height 16 \
}
wvGetSignalClose -win $_nWave2
wvZoomAll -win $_nWave2

