wvCreateWindow
verdiSetActWin -win $_nWave2
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_minisoc_aes_dp"
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1_CHAVES" \
{/tb_minisoc_aes_dp/clk} -height 16 \
{/tb_minisoc_aes_dp/rst_n} -height 16 \
{/tb_minisoc_aes_dp/chave_start} -height 16 \
{/tb_minisoc_aes_dp/chave_mestra\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/chave_indice\[3:0\]} -height 16 \
{/tb_minisoc_aes_dp/subchave_atual\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/chave_pronta} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G2_AES_DATAPATH" \
{/tb_minisoc_aes_dp/aes_start} -height 16 \
{/tb_minisoc_aes_dp/modo_decrypt} -height 16 \
{/tb_minisoc_aes_dp/bloco_entrada\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/round_q\[3:0\]} -height 16 \
{/tb_minisoc_aes_dp/u_dut_dp/state_q\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/bloco_saida\[127:0\]} -height 16 \
{/tb_minisoc_aes_dp/aes_ocupado} -height 16 \
{/tb_minisoc_aes_dp/aes_pronto} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G3_STATUS" \
{/tb_minisoc_aes_dp/pass_cnt\[31:0\]} -height 16 \
{/tb_minisoc_aes_dp/err_cnt\[31:0\]} -height 16 \
}
wvGetSignalClose -win $_nWave2
wvZoomAll -win $_nWave2
