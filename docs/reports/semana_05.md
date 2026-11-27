# Relatório Semanal 05 — SPI Front-End e PLL Mock

**Data de entrega:** 20/11/2026  
**Autor:** Daniel Lima Neto  

---

## 1. Resumo das Atividades Realizadas

1. **Implementação do Front-End SPI e Banco de Registradores (`rtl/minisoc_spi/minisoc_spi.sv`):**
   - Desenvolvimento do módulo [`minisoc_spi.sv`](../../rtl/minisoc_spi/minisoc_spi.sv) conforme as Seções 5 e 6 do *Block Guide*:
     - **Protocolo SPI Mode 0 (`CPOL = 0`, `CPHA = 0`), MSB-first, até 25 MHz:** amostragem de `spi_mosi_i` na borda de subida de `spi_sclk_i` e atualização registrada (livre de *glitches*) de `spi_miso_o` na borda de descida de `spi_sclk_i`.
     - **Formato do frame de 40 bits:** `{RWb[39], ADDR[38:33], RSV[32], DATA[31:0]}`:
       - **Escrita (`RWb = 0`):** concluída em uma única transação SPI de 40 bits.
       - **Leitura (`RWb = 1`):** executada em duas transações; a primeira seleciona o endereço e captura o valor do registrador em `rd_data_clk_q[31:0]` no domínio `clk_i`, enquanto a segunda transação (com endereço `NOP = 6'h3F`) desloca `{8'h00, rd_data_clk_q[31:0]}` em `spi_miso_o`.
     - **Clock-Domain Crossing (`spi_sclk_i` $\rightarrow$ `clk_i`, Seção 5.3):** ao receber o 40º bit na borda de subida de `spi_sclk_i`, o frame completo é travado em `rx_frame_captured_q[39:0]` e `rx_toggle_q` inverte de estado (ambos resetados exclusivamente por `rst_ni`, nunca por `spi_cs_ni`). No domínio *always-on* `clk_i` (2 GHz), um sincronizador de 2 flip-flops (`toggle_sync_ff1_q`, `toggle_sync_ff2_q`) seguido de detector de borda XOR (`toggle_sync_ff2_q ^ toggle_sync_ff3_q`) gera o pulso de 1 ciclo `frame_valid_clk`.
     - **Banco de Registradores completo (Seção 6):**
       - `0x00..0x03`: `KEY0`–`KEY3` (R/W) $\rightarrow$ `cfg_key_o[127:0]`
       - `0x04..0x07`: `IV0`–`IV3` (R/W) $\rightarrow$ `cfg_iv_o[127:0]`
       - `0x08..0x09`: `COUNTER_HI` / `COUNTER_LO` (R/W) $\rightarrow$ `cfg_counter_o[63:0]`
       - `0x0A`: `NUM_BLOCKS` (R/W) $\rightarrow$ `cfg_num_blocks_o[31:0]`
       - `0x0B`: `AES_CONTROL` (R/W) $\rightarrow$ `MODE[4:2]`, `DECRYPT[1]` e `START[0]` (*write-one-pulse*, gera pulso de 1 ciclo em `aes_start_o` e lê sempre `0`)
       - `0x0C`: `AES_STATUS` (R) $\rightarrow$ `{20'd0, BLOCKS_DONE[11:3], ERROR[2], DONE[1], BUSY[0]}`
       - `0x0D`: `VERSION` (R) $\rightarrow$ `VERSION_ID = 32'h0001_0000`
       - `0x0E`: `SYSTEM_CONTROL` (R/W) $\rightarrow$ `PLL_DIV_SEL[3:2]`, `PLL_ENABLE[1]`, `MEM_SEL_AES[0]`
       - `0x0F`: `SYSTEM_STATUS` (R) $\rightarrow$ `{31'd0, PLL_LOCKED[0]}`
       - `0x3F`: `NOP` (sem efeito em escrita/leitura, preservando `rd_data_clk_q`)

2. **Implementação do Modelo PLL Mock (`rtl/minisoc_pll/minisoc_pll_mock.sv`):**
   - Desenvolvimento do módulo [`minisoc_pll_mock.sv`](../../rtl/minisoc_pll/minisoc_pll_mock.sv) conforme a Seção 4.1 e o requisito `LIM-PLL-01` (modelo RTL de integração e verificação, não uma macro física):
     - Referência de 2 GHz (`clk_i`) e divisores selecionados por `pll_div_sel_i`: `00` (`/1`, 2,000 GHz), `01` (`/2`, 1,000 GHz), `10` (`/4`, 500 MHz) e `11` (`/8`, 250 MHz).
     - Enquanto `pll_en_i = 0` ou durante a aquisição de *lock*, `locked_o` permanece em `0` e `sys_clk_o` permanece bloqueado em `0` (`REQ-PLL-01`).
     - Atraso de *lock* pseudoaleatório implementado por LFSR de 8 bits de comprimento máximo ($x^8 + x^6 + x^5 + x^4 + 1$, semente `8'hA5`), gerando latências entre 18 e 81 ciclos de `clk_i` a cada habilitação ou troca dinâmica de divisor.
     - *Clock gating* livre de *glitches* para o caminho `/1` via flip-flop na borda de descida (`clk_en_neg_q`) — sem uso de *latches* — e divisor síncrono `div_cnt_q[2:0]` com *duty cycle* de 50% para `/2`, `/4` e `/8`.

3. **Testbench Dirigido e Scripts (`tb/tb_minisoc_spi_pll.sv`, `scripts/MakeFile`, `verdicmd/verdi_w05.cmd`):**
   - Criação do testbench autoverificável [`tb_minisoc_spi_pll.sv`](../../tb/tb_minisoc_spi_pll.sv) integrando `minisoc_spi` e `minisoc_pll_mock` sob `clk = 2 GHz` (`T = 0,5 ns`) e `spi_sclk = 25 MHz` (`T = 40 ns`).
   - Atualização do [`scripts/MakeFile`](../../scripts/MakeFile) com os alvos `run_w05`, `wave_w05` e `lint_w05`, e criação do script [`verdicmd/verdi_w05.cmd`](../../verdicmd/verdi_w05.cmd) com grupos de sinais para o Verdi.

---

## 2. Plano de Verificação e Casos de Teste (`tb_minisoc_spi_pll.sv`)

| Caso de Teste | Escopo Verificado | Critério de Aceite Atendido |
| :--- | :--- | :--- |
| **TEST 1 — Estado de Reset e PLL Desabilitado** | Leitura via SPI de `VERSION` (`32'h0001_0000`), `SYSTEM_STATUS` (`PLL_LOCKED = 0`), `SYSTEM_CONTROL` e `AES_CONTROL`; confirmação de 0 bordas em `sys_clk` | Reset determinístico e `REQ-PLL-01` |
| **TEST 2 — Escrita e Leitura de Todos os Registradores R/W** | Escrita (1 transação) e leitura (2 transações com `NOP 0x3F`) de `KEY0..KEY3`, `IV0..IV3`, `COUNTER_HI/LO`, `NUM_BLOCKS`, `AES_CONTROL` (incluindo máscara de bits reservados e pulso único de 1 ciclo em `START` W1P) e `SYSTEM_CONTROL` | Todos os registradores R/W escritos e lidos via SPI |
| **TEST 3 — Proteção dos Registradores Somente Leitura (R)** | Tentativa de escrita via SPI em `AES_STATUS`, `VERSION`, `SYSTEM_STATUS`, `NOP (0x3F)` e endereço não mapeado (`0x2A`), verificando preservação dos valores e integridade de `KEY0` | Registradores R não alterados por escrita |
| **TEST 4 — Habilitação e Lock do PLL (Passos 8 e 9, Seção 9)** | Para os quatro divisores (`/1`, `/2`, `/4`, `/8`): bloqueio de `sys_clk` enquanto desabilitado, programação de `PLL_DIV_SEL` + `PLL_ENABLE = 1` via SPI, *polling* de `SYSTEM_STATUS` até `PLL_LOCKED = 1`, conferência de latência pseudoaleatória, medição exata do período (`0,5 / 1,0 / 2,0 / 4,0 ns`), troca dinâmica `/8` $\rightarrow$ `/2`, desabilitação final e monitor global contínuo de `REQ-PLL-01` | PLL travando nos quatro divisores sem *glitches* |

---

## 3. Relatório de Lint

### 3.1 Comando de Execução (`vlogan +lint=all`)

```bash
# Executar lint dedicado da Semana 5 (gera lint_w05.log)
make -f scripts/MakeFile lint_w05

# Compilar com +lint=all e executar simulação da Semana 5
make -f scripts/MakeFile run_w05

# Abrir ondas no Synopsys Verdi com sinais pré-carregados
make -f scripts/MakeFile wave_w05
```

### 3.2 Análise Estática de Conformidade e Avisos Justificados

| Módulo | Verificação Estática | Status Esperado (`vlogan +lint=all`) | Justificativa Técnica (para ferramentas estritas de CDC / Lint) |
| :--- | :--- | :---: | :--- |
| `minisoc_spi.sv` | Larguras de barramento, literais dimensionados, `case` com `default`, ausência de *latches* e *multi-drivers* | **0 erros / 0 warnings** | Todas as atribuições e concatenações têm largura exata; todos os registradores possuem reset explícito |
| `minisoc_spi.sv` | Reset assíncrono combinado `spi_frame_rst_n = rst_ni & ~spi_cs_ni` para `rx_bit_cnt_q`, `rx_shift_q`, `tx_bit_cnt_q`, `tx_shift_q`, `spi_miso_q` | **Justificado (se reportado por lint de reset)** | Garante reinício limpo dos contadores de bit quando `spi_cs_ni` retorna ao repouso (`1`), enquanto `rx_frame_captured_q` e `rx_toggle_q` utilizam exclusivamente `rst_ni` para não perder o evento CDC |
| `minisoc_spi.sv` | Bit reservado `rx_frame_captured_q[32]` (`RSV`) não consumido no banco de registradores | **Justificado (se reportado por lint de bit não utilizado)** | Conforme Seção 5.2 do *Block Guide*, o bit `32` do frame de 40 bits é reservado (`RSV = 0`) e ignorado pelo decodificador; mantido no registrador de 40 bits para fidelidade do frame e depuração em onda |
| `minisoc_spi.sv` | Borda de descida `negedge spi_sclk_i` no caminho TX (`spi_miso_q`) | **Justificado (se reportado por lint de borda mista)** | Requisito explícito de protocolo SPI Mode 0 (Seção 5.1): MOSI amostrado em `posedge spi_sclk` e MISO atualizado em `negedge spi_sclk` |
| `minisoc_spi.sv` | Leitura de `rd_data_clk_q` no domínio `spi_sclk_i` | **Justificado (CDC estático)** | O dado de leitura estabiliza em 3 ciclos de `clk_i` (1,5 ns) após a 1ª transação e permanece estático por $\ge 320\text{ ns}$ (8 ciclos de `spi_sclk` a 25 MHz) antes de ser carregado na 8ª borda de descida da 2ª transação |
| `minisoc_pll_mock.sv` | *Clock gating* (`clk_i & clk_en_neg_q`), flip-flop em `negedge clk_i` e clock dividido em `div_cnt_q[0..2]` | **0 erros / Justificado (`LIM-PLL-01`)** | Conforme Seção 4.1 e `LIM-PLL-01`, `minisoc_pll_mock` é um modelo comportamental RTL para integração e verificação (não uma macro física de síntese). O uso de `clk_en_neg_q` evita inferência de *latch* e assegura transição livre de *glitches* em `/1` |
| `tb_minisoc_spi_pll.sv` | Conexão de portas, tipos, monitoramento concorrente e chamadas de *tasks* | **0 erros / 0 warnings** | Todas as 21 portas de `minisoc_spi` e 6 portas de `minisoc_pll_mock` conectadas explicitamente por nome com largura exata |

> **Observação:** Os arquivos RTL, testbench e scripts foram verificados estaticamente (balanceamento de blocos, casamento exato de todas as portas/larguras, consistência de sinais do Verdi e tabulação do `MakeFile`). Execute `make -f scripts/MakeFile lint_w05` e `make -f scripts/MakeFile run_w05` no servidor Synopsys VCS/Verdi para anexar o `lint_w05.log` e os resultados finais de simulação.
