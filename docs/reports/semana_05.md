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

## 2. Resultados da Simulação (`tb_minisoc_spi_pll.sv` — Synopsys VCS)

A simulação no Synopsys VCS encerrou em `160913250 ps` (`160,91325 µs`) com **0 erros e 53/53 verificações aprovadas (`OVERALL RESULT: PASS`)**:

| Caso de Teste | Escopo Verificado | Valores Obtidos na Simulação | Resultado |
| :--- | :--- | :--- | :---: |
| **TEST 1 — Estado de Reset e PLL Desabilitado** | Leitura via SPI de `VERSION` (`0x0D`), `SYSTEM_STATUS` (`0x0F`), `SYSTEM_CONTROL` (`0x0E`) e `AES_CONTROL` (`0x0B`); monitor de `sys_clk` | `VERSION = 32'h00010000`, demais `32'h00000000`, `0` bordas em `sys_clk` | **PASS (5/5)** |
| **TEST 2 — Escrita e Leitura de Todos os Registradores R/W** | `KEY0..KEY3`, `IV0..IV3`, `COUNTER_HI/LO`, `NUM_BLOCKS`, `AES_CONTROL` (máscara + pulso `START` W1P de 1 ciclo e auto-limpeza) e `SYSTEM_CONTROL` | `cfg_key_o = 00010203..0c0d0e0f`, `cfg_iv_o = 10111213..1c1d1e1f`, `cfg_counter_o = deadbeefcafebabe`, `cfg_num_blocks_o = 256`, `AES_CONTROL = 32'h00000016` $\rightarrow$ `32'h00000008` (1 pulso W1P), `SYSTEM_CONTROL = 32'h0000000d` $\rightarrow$ `32'h00000000` | **PASS (22/22)** |
| **TEST 3 — Proteção dos Registradores Somente Leitura (R)** | Leitura de `AES_STATUS` e tentativas de escrita em `AES_STATUS` (`0x0C`), `VERSION` (`0x0D`), `SYSTEM_STATUS` (`0x0F`), `NOP` (`0x3F`) e endereço não mapeado (`0x2A`) | `AES_STATUS = 32'h0000044b` (`BLOCKS_DONE=137`, `DONE=1`, `BUSY=1`), `VERSION = 32'h00010000`, `SYSTEM_STATUS = 32'h00000000`, `KEY0 = 32'h00010203` intactos após escritas | **PASS (5/5)** |
| **TEST 4 — Habilitação e Lock do PLL (Passos 8 e 9, Seção 9)** | Habilitação via SPI, *polling* de `SYSTEM_STATUS` até `PLL_LOCKED = 1` e medição de período nos 4 divisores + troca dinâmica `/8` $\rightarrow$ `/2` + monitor global `REQ-PLL-01` | `/1`: `T = 0,500 ns` (lock em `72` ciclos)<br>`/2`: `T = 1,000 ns` (lock em `70` ciclos)<br>`/4`: `T = 2,000 ns` (lock em `41` ciclos)<br>`/8`: `T = 4,000 ns` (lock em `47` ciclos)<br>Troca dinâmica `/8` $\rightarrow$ `/2`: `T = 1,000 ns`<br>Monitor `REQ-PLL-01`: `0` bordas indevidas | **PASS (21/21)** |

---

## 3. Relatório de Lint (`vlogan +lint=all`)

### 3.1 Comando Executado e Resumo do Log (`Synopsys VCS X-2025.06-SP2_Full64`)

```bash
vlogan -full64 -sverilog -kdb -timescale=1ns/1ps +lint=all \
	rtl/minisoc_spi/minisoc_spi.sv \
	rtl/minisoc_pll/minisoc_pll_mock.sv \
	tb/tb_minisoc_spi_pll.sv | tee lint_w05.log
```

| Arquivo Analisado | Erros | Warnings / Lint no RTL | Avisos de Lint (`+lint=all`) | Status |
| :--- | :---: | :---: | :---: | :---: |
| [`rtl/minisoc_spi/minisoc_spi.sv`](../../rtl/minisoc_spi/minisoc_spi.sv) | **0** | **0** | **0** | **LIMPO (100%)** |
| [`rtl/minisoc_pll/minisoc_pll_mock.sv`](../../rtl/minisoc_pll/minisoc_pll_mock.sv) | **0** | **0** | **0** | **LIMPO (100%)** |
| [`tb/tb_minisoc_spi_pll.sv`](../../tb/tb_minisoc_spi_pll.sv) | **0** | — | **14 `Lint-[NS]`** (*Null statement*, apenas no testbench) | **APROVADO (Justificado)** |

### 3.2 Justificativa Técnica dos Avisos `Lint-[NS]` e Decisões de Projeto

| Código / Escopo | Ocorrências (Linhas) | Descrição da Ferramenta | Justificativa Técnica |
| :--- | :--- | :--- | :--- |
| **`Lint-[NS]` (*Null statement*)** em `tb/tb_minisoc_spi_pll.sv` | Linhas `206`, `209`, `213`, `216` (`#(SPI_HALF_PERIOD);`), `259`, `261` (`repeat (N) @(posedge sys_clk);`), `266` (`#200.0;`), `303`, `305`, `329`, `469`, `512`, `604`, `636` (`repeat (N) @(posedge clk);`) | Na gramática IEEE 1800, um controle de atraso (`#d;`) ou controle de evento (`repeat(N) @(posedge clk);`) finalizado por ponto e vírgula sem comando associado na mesma instrução é interpretado pelo parser do `vlogan +lint=all` como um controle temporal aplicado a uma instrução nula (`;`). | **Totalmente benigno e restrito ao testbench (não sintetizável):** são esperas temporais intencionais do BFM mestre SPI (meio período de 20 ns do `spi_sclk` a 25 MHz) e esperas de ciclos de `clk`/`sys_clk` para sincronização de estímulos e *timeout*. **Os módulos RTL (`minisoc_spi.sv` e `minisoc_pll_mock.sv`) compilaram com 0 erros e 0 avisos.** |
| **Reset de frame SPI (`spi_frame_rst_n`)** em `minisoc_spi.sv` | `spi_frame_rst_n = rst_ni & ~spi_cs_ni` | Nenhum aviso emitido pelo `vlogan +lint=all` (`0 warnings`). | Garante o zeramento imediato dos contadores de bit (`rx_bit_cnt_q`, `tx_bit_cnt_q`) ao final da transação (`spi_cs_ni = 1`), enquanto `rx_frame_captured_q` e `rx_toggle_q` são resetados exclusivamente por `rst_ni` para preservar o evento CDC. |
| **Modelo de Integração PLL (`LIM-PLL-01`)** em `minisoc_pll_mock.sv` | `clk_en_neg_q` (`negedge clk_i`) e `div_cnt_q[2:0]` | Nenhum aviso emitido pelo `vlogan +lint=all` (`0 warnings`). | O uso de flip-flop na borda de descida (`clk_en_neg_q`) evita inferência de *latch* e garante *clock gating* livre de *glitches* para o divisor `/1` (2 GHz), cumprindo `REQ-PLL-01` e `LIM-PLL-01`. |
