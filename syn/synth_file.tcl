# ============================================================
# Script de Síntese - Synopsys Design Compiler
# ============================================================

# 1. Nome do módulo top-level a sintetizar
# Pode ser: minisoc_aes_sub_bytes, minisoc_aes_shift_rows, minisoc_aes_sbox
set DESIGN_NAME "minisoc_aes_sub_bytes"

# Garantir existência do diretório de relatórios
file mkdir reports

# ------------------------------------------------------------
# 2. Carregar bibliotecas e search path
# ------------------------------------------------------------
set search_path [list . .. ../libs]
set target_library "saed32rvt_tt1v25c.db"
set link_library "* $target_library"

# ------------------------------------------------------------
# 3. Ler e Analisar arquivos RTL (SystemVerilog)
# ------------------------------------------------------------
# O comando analyze requer arquivos explicitamente (não apenas o diretório)
set RTL_FILES [list \
    ../rtl/minisoc_aes/minisoc_aes_sbox.sv \
    ../rtl/minisoc_aes/minisoc_aes_sub_bytes.sv \
    ../rtl/minisoc_aes/minisoc_aes_shift_rows.sv \
]

analyze -format sverilog $RTL_FILES

# ------------------------------------------------------------
# 4. Elaborar o módulo e vincular
# ------------------------------------------------------------
elaborate $DESIGN_NAME
current_design $DESIGN_NAME
link

# ------------------------------------------------------------
# 5. Restrições Temporais (SDC / Constraints)
# ------------------------------------------------------------
if {[file exists "${DESIGN_NAME}.sdc"]} {
    read_sdc "${DESIGN_NAME}.sdc"
} elseif {[file exists "minisoc_top.sdc"]} {
    read_sdc "minisoc_top.sdc"
} else {
    # Para blocos puramente combinacionais da Semana 2, cria restrição de max_delay
    set_max_delay 2.0 -from [all_inputs] -to [all_outputs]
}

# ------------------------------------------------------------
# 6. Verificação e Relatórios Pré-Síntese
# ------------------------------------------------------------
puts "\n=================================================="
puts "CHECK DESIGN"
puts "=================================================="

redirect reports/check_design.rpt {
    check_design
}

redirect reports/area_pre.rpt {
    report_area -hierarchy
}

redirect reports/timing_pre.rpt {
    report_timing -max_paths 10
}

# ------------------------------------------------------------
# 7. Síntese Lógica (Compile Ultra)
# ------------------------------------------------------------
puts "\n=================================================="
puts "INICIANDO SÍNTESE (COMPILE ULTRA)"
puts "=================================================="

set_svf reports/${DESIGN_NAME}.svf

compile_ultra

# ------------------------------------------------------------
# 8. Relatórios Pós-Síntese
# ------------------------------------------------------------
redirect reports/report_area.rpt {
    report_area -hierarchy
}

redirect reports/report_timing.rpt {
    report_timing -max_paths 10
}

redirect reports/report_power.rpt {
    report_power -hierarchy
}

redirect reports/report_constraint.rpt {
    report_constraint -all_violators
}

# ------------------------------------------------------------
# 9. Exportar Netlist e DDC
# ------------------------------------------------------------
write -format verilog -hierarchy -output ${DESIGN_NAME}_syn.v
write -format ddc -hierarchy -output ${DESIGN_NAME}_syn.ddc

puts "\n=================================================="
puts "SÍNTESE CONCLUÍDA COM SUCESSO"
puts "=================================================="
puts "Netlist gerada: syn/${DESIGN_NAME}_syn.v"
puts "Relatórios salvos em: syn/reports/"
puts "=================================================="
