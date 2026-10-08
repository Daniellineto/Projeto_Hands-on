# ============================================================
# Script de Síntese - Template
# ============================================================

# Nome do módulo top-level (Preencha depois)
set DESIGN_NAME ""

# ------------------------------------------------------------
# Carregar configuração 
# ------------------------------------------------------------
set search_path [list . ../libs]
set target_library "saed32rvt_tt1v25c.db"
set link_library "* $target_library"

# ------------------------------------------------------------
# Ler RTL
# ------------------------------------------------------------
# Altere para apontar os arquivos .sv específicos ou a pasta toda
analyze -format sverilog ../rtl/

# ------------------------------------------------------------
# Elaborar
# ------------------------------------------------------------
if {$DESIGN_NAME != ""} {
    elaborate $DESIGN_NAME
}

link

# ------------------------------------------------------------
# Constraints
# ------------------------------------------------------------
# read_sdc ${DESIGN_NAME}.sdc

# ------------------------------------------------------------
# Verificação do design
# ------------------------------------------------------------
puts "\n=================================================="
puts "CHECK DESIGN"
puts "=================================================="

redirect reports/check_design.rpt {
    check_design
}

# ------------------------------------------------------------
# Relatórios pré-síntese
# ------------------------------------------------------------

redirect reports/area_pre.rpt {
    report_area -hierarchy
}

redirect reports/timing_pre.rpt {
    report_timing -max_paths 10
}

# ------------------------------------------------------------
# Síntese
# ------------------------------------------------------------
puts "\n=================================================="
puts "INICIANDO SÍNTESE (COMPILE ULTRA)"
puts "=================================================="

set_svf reports/default.svf
compile_ultra 

#-------------------------------------------------------------
# Relatórios pós-síntese
# ------------------------------------------------------------

redirect reports/report_area.rpt {
    report_area
}

redirect reports/report_timing.rpt {
    report_timing
}

redirect reports/report_power.rpt {
    report_power
}

redirect reports/report_constraint.rpt {
    report_constraint -all_violators
}

# ------------------------------------------------------------
# Exportar netlist
# ------------------------------------------------------------

if {$DESIGN_NAME != ""} {
    write -format verilog -hierarchy -output ${DESIGN_NAME}_syn.v
    write -format ddc -hierarchy -output ${DESIGN_NAME}_syn.ddc
    write_file -format ddc -hierarchy -output ${DESIGN_NAME}.ddc
}

puts "\n=================================================="
puts "SÍNTESE CONCLUÍDA"
puts "=================================================="
puts "Arquivos gerados na pasta reports/ :"
puts "  reports/check_design.rpt"
puts "  reports/area_pre.rpt"
puts "  reports/timing_pre.rpt"
puts "  reports/report_area.rpt"
puts "  reports/report_timing.rpt"
puts "  reports/report_power.rpt"
puts "  reports/report_constraint.rpt"
puts "Arquivos gerados na pasta syn/ :"
puts "  ${DESIGN_NAME}_syn.v"
puts "  ${DESIGN_NAME}_syn.ddc"
puts "  ${DESIGN_NAME}.ddc"
puts "=================================================="
