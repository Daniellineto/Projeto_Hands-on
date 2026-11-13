verdiSetActWin -win $_OneSearch
simSetSimulator "-vcssv" -exec \
           "./simv" \
           -args
debImport "-dbdir" \
          "./simv.daidir"
debLoadSimResult \
           ./waves.fsdb
wvCreateWindow
verdiSetActWin -win $_nWave2
verdiWindowResize -win $_Verdi_1 "248" "29" "1223" "616"
verdiSetActWin -dock widgetDock_MTB_SOURCE_TAB_1
wvGetSignalOpen -win $_nWave2
wvGetSignalSetScope -win $_nWave2 "/tb_minisoc_aes_sub_shift"
verdiSetActWin -win $_nWave2
verdiWindowResize -win $_Verdi_1 "0" "29" "798" "513"
wvSetPosition -win $_nWave2 {("G1" 5)}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvAddSignal -win $_nWave2 -clear
wvAddSignal -win $_nWave2 -group {"G1" \
{/tb_minisoc_aes_sub_shift/sbox_in\[7:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/sbox_out\[7:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/inv_sbox_in\[7:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/inv_sbox_out\[7:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/err_cnt\[31:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G2" \
{/tb_minisoc_aes_sub_shift/fwd_state_in\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/fwd_after_sub_bytes\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/fwd_after_shift_rows\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/fwd_after_mix_columns\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/fwd_round_key\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/fwd_ark_in\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/fwd_after_ark\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/err_cnt\[31:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G3" \
{/tb_minisoc_aes_sub_shift/inv_state_in\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/inv_after_shift_rows\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/inv_after_sub_bytes\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/inv_round_key\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/inv_ark_in\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/inv_after_ark\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/inv_after_mix_columns\[127:0\]} -height 16 \
{/tb_minisoc_aes_sub_shift/err_cnt\[31:0\]} -height 16 \
}
wvAddSignal -win $_nWave2 -group {"G4" \
}
wvSelectSignal -win $_nWave2 {( "G1" 5 )}
wvSetPosition -win $_nWave2 {("G1" 5)}
wvGetSignalClose -win $_nWave2
verdiWindowResize -win $_Verdi_1 "248" "29" "1223" "616"
wvZoomAll -win $_nWave2
