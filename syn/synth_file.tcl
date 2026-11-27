# ============================================================
# Script de Síntese - Synopsys Design Compiler
# ============================================================

# 1. Nome do módulo top-level a sintetizar
# Pode ser sobrescrito via variável de ambiente SYNTH_TOP:
#   make -f scripts/MakeFile synth SYNTH_TOP=minisoc_aes_top
#   make -f scripts/MakeFile synth_spi
#   make -f scripts/MakeFile synth_aes_top
#   make -f scripts/MakeFile synth_aes_dp
if {[info exists ::env(SYNTH_TOP)] && $::env(SYNTH_TOP) ne ""} {
    set DESIGN_NAME $::env(SYNTH_TOP)
} else {
    set DESIGN_NAME "minisoc_aes_top"
}

puts "\n=================================================="
puts "SINTETIZANDO MÓDULO: ${DESIGN_NAME}"
puts "=================================================="

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
set RTL_FILES [list \
    ../rtl/minisoc_aes/minisoc_aes_sbox.sv \
    ../rtl/minisoc_aes/minisoc_aes_sub_bytes.sv \
    ../rtl/minisoc_aes/minisoc_aes_shift_rows.sv \
    ../rtl/minisoc_aes/minisoc_aes_mix_columns.sv \
    ../rtl/minisoc_aes/minisoc_aes_add_round_key.sv \
    ../rtl/minisoc_aes/minisoc_aes_inv_sbox.sv \
    ../rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv \
    ../rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv \
    ../rtl/minisoc_aes/minisoc_aes_inv_mix_columns.sv \
    ../rtl/minisoc_aes/minisoc_aes_key_exp.sv \
    ../rtl/minisoc_aes/minisoc_aes_dp.sv \
    ../rtl/minisoc_aes/minisoc_aes_top.sv \
    ../rtl/minisoc_spi/minisoc_spi.sv \
    ../rtl/minisoc_pll/minisoc_pll_mock.sv \
    ../rtl/minisoc_mem/minisoc_memory.sv \
]

analyze -format sverilog $RTL_FILES

# ------------------------------------------------------------
# 4. Elaborar o módulo e vincular
# ------------------------------------------------------------
elaborate $DESIGN_NAME
current_design $DESIGN_NAME
link

# ------------------------------------------------------------
# 5. Restrições Temporais (SDC / Constraints Automáticas por Bloco)
# ------------------------------------------------------------
if {[file exists "${DESIGN_NAME}.sdc"]} {
    read_sdc "${DESIGN_NAME}.sdc"
} elseif {[file exists "minisoc_top.sdc"]} {
    read_sdc "minisoc_top.sdc"
} else {
    # Constraints automáticas de acordo com as portas de clock do módulo
    if {$DESIGN_NAME eq "minisoc_spi"} {
        # clk_i = 2 GHz (0.5 ns), spi_sclk_i = 25 MHz (40.0 ns), domínios assíncronos
        create_clock -name clk_i      -period 0.5  [get_ports clk_i]
        create_clock -name spi_sclk_i -period 40.0 [get_ports spi_sclk_i]
        set_clock_groups -asynchronous -group [get_clocks clk_i] -group [get_clocks spi_sclk_i]
        set_false_path -from [get_ports rst_ni]
    } elseif {[sizeof_collection [get_ports -quiet clk_i]] > 0} {
        # Módulos síncronos a clk_i (minisoc_aes_top, minisoc_aes_dp, minisoc_aes_key_exp, minisoc_pll_mock)
        create_clock -name clk_i -period 2.0 [get_ports clk_i]
        if {[sizeof_collection [get_ports -quiet rst_ni]] > 0} {
            set_false_path -from [get_ports rst_ni]
        }
    } elseif {[sizeof_collection [get_ports -quiet ext_clk_i]] > 0} {
        # minisoc_memory (ext_clk_i até 200 MHz = 5.0 ns, aes_clk_i = 2.0 ns)
        create_clock -name ext_clk_i -period 5.0 [get_ports ext_clk_i]
        create_clock -name aes_clk_i -period 2.0 [get_ports aes_clk_i]
        set_clock_groups -physically_exclusive -group [get_clocks ext_clk_i] -group [get_clocks aes_clk_i]
    } else {
        # Submódulos puramente combinacionais (S-Box, SubBytes, ShiftRows, MixColumns, AddRoundKey)
        set_max_delay 2.0 -from [all_inputs] -to [all_outputs]
    }
}

# ------------------------------------------------------------
# 6. Verificação e Relatórios Pré-Síntese
# ------------------------------------------------------------
puts "\n=================================================="
puts "CHECK DESIGN (${DESIGN_NAME})"
puts "=================================================="

redirect reports/check_design.rpt {
    check_design
}
redirect reports/${DESIGN_NAME}_check_design.rpt {
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
puts "INICIANDO SÍNTESE (COMPILE ULTRA) - ${DESIGN_NAME}"
puts "=================================================="

set_svf reports/${DESIGN_NAME}.svf

compile_ultra

# ------------------------------------------------------------
# 8. Relatórios Pós-Síntese
# ------------------------------------------------------------
redirect reports/report_area.rpt {
    report_area -hierarchy
}
redirect reports/${DESIGN_NAME}_area.rpt {
    report_area -hierarchy
}

redirect reports/report_timing.rpt {
    report_timing -max_paths 10
}
redirect reports/${DESIGN_NAME}_timing.rpt {
    report_timing -max_paths 10
}

redirect reports/report_power.rpt {
    report_power -hierarchy
}
redirect reports/${DESIGN_NAME}_power.rpt {
    report_power -hierarchy
}

redirect reports/report_constraint.rpt {
    report_constraint -all_violators
}
redirect reports/${DESIGN_NAME}_qor.rpt {
    report_qor
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

exit
