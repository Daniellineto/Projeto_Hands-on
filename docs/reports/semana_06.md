# Relatório Semanal 06 — AES Engine e Memória Compartilhada

**Data de entrega:** 27/11/2026  
**Autor:** Daniel Lima Neto  

---

## 1. Resumo das Atividades Realizadas

1. **Implementação da Memória Compartilhada e Arbitragem (`rtl/minisoc_mem/minisoc_memory.sv`):**
   - Desenvolvimento do módulo [`minisoc_memory.sv`](../../rtl/minisoc_mem/minisoc_memory.sv) conforme a Seção 7 e o requisito `LIM-MEM-01` do *Block Guide*:
     - Memória SRAM *single-port* síncrona de **1024 $\times$ 32 bits** (capacidade máxima de **256 blocos AES de 128 bits**, 4 palavras consecutivas por bloco: `base+0 = [127:96]`, `base+1 = [95:64]`, `base+2 = [63:32]`, `base+3 = [31:0]`).
     - Sem reset funcional sobre o array de memória (`logic [31:0] mem [0:1023]`), preservando o conteúdo carregado conforme as Seções 3 e 7.3.
     - Multiplexador de *ownership* controlado por `mem_sel_aes_i` (`SYSTEM_CONTROL.MEM_SEL_AES`):
       - `mem_sel_aes_i = 0`: endereço (`ext_addr_i`), dado de escrita (`ext_wdata_i`), *write-enable* (`ext_wr_en_i`) e relógio (`ext_clk_i`) provêm da interface externa `MEMORY DATA`.
       - `mem_sel_aes_i = 1`: endereço (`aes_addr_i`), dado de escrita (`aes_wdata_i`), *write-enable* (`aes_wr_en_i`) e relógio (`aes_clk_i`) provêm exclusivamente do `minisoc_aes_top`.

2. **Implementação do Controlador Multi-Bloco AES (`rtl/minisoc_aes/minisoc_aes_top.sv`):**
   - Desenvolvimento do módulo [`minisoc_aes_top.sv`](../../rtl/minisoc_aes/minisoc_aes_top.sv) conforme a Seção 8 do *Block Guide* e o documento de microarquitetura:
     - **Captura e Validação no `START`:** ao detectar `start_i = 1` em `ST_IDLE`, captura `KEY`, `IV`, `COUNTER`, `MODE`, `DECRYPT` e `NUM_BLOCKS` e transita para `ST_VALIDATE`.
     - **Detecção de Configuração Inválida:** verifica se $1 \le \texttt{NUM\_BLOCKS} \le 256$ e se `MODE` pertence aos modos implementados na v1.0 (`ECB = 3'b000`, `CBC = 3'b001`, `CTR = 3'b101`). Configurações fora desse intervalo sinalizam imediatamente `error_o = 1`, `busy_o = 0`, `done_o = 0`, `blocks_done_o = 0` e encerram a operação em `ST_IDLE` sem acessar ou alterar a memória.
     - **Processamento Multi-Bloco *In-Place*:**
       1. Executa a pré-expansão das 11 subchaves uma única vez no início do lote (`ST_KEY_EXP`, 10 ciclos em [`minisoc_aes_key_exp.sv`](../../rtl/minisoc_aes/minisoc_aes_key_exp.sv)).
       2. Para cada bloco $i \in \{0 \dots \texttt{NUM\_BLOCKS}-1\}$:
          - Lê 4 palavras de 32 bits nos endereços `4*i + 0..3` (`ST_RD_W0..ST_RD_WAIT`) recompondo `rd_block_q[127:0]`.
          - Dispara [`minisoc_aes_dp.sv`](../../rtl/minisoc_aes/minisoc_aes_dp.sv) (`ST_DP_START` $\rightarrow$ `ST_PROCESS_DP`, 10 rodadas) de acordo com o modo selecionado:
            - **ECB (`3'b000`):** cifra (`DECRYPT=0`) ou decifra (`DECRYPT=1`) `rd_block_q` diretamente.
            - **CBC (`3'b001`):** na cifragem (`DECRYPT=0`), aplica XOR prévio `rd_block_q ^ chain_vec_q` (inicializado com `IV`) e atualiza `chain_vec_q <= dp_block_out`; na decriptação (`DECRYPT=1`), decifra `rd_block_q`, aplica XOR final `dp_block_out ^ chain_vec_q` e atualiza `chain_vec_q <= rd_block_q`.
            - **CTR (`3'b101`):** utiliza sempre o caminho direto (*AES Encrypt*, `dp_decrypt = 0`) sobre `IV ^ {64'd0, ctr_q}`, aplica XOR entre o *keystream* gerado e o bloco lido (`wr_block_q <= rd_block_q ^ dp_block_out`) e incrementa `ctr_q <= ctr_q + 64'd1` a cada bloco.
          - Escreve as 4 palavras de 32 bits de `wr_block_q[127:0]` de volta *in-place* nos mesmos endereços `4*i + 0..3` (`ST_WR_W0..ST_WR_W3`) e incrementa `blocks_done_o` (`ST_CHECK_NEXT`).
       3. Ao concluir o último bloco (`ST_FINISH`), desativa `busy_o = 0` e mantém `done_o = 1` (*sticky*) até que um novo `start_i` válido seja aceito.

3. **Modelo de Referência em Python e Vetores Golden (`scripts/gen_aes_ref_vectors.py`, `tb/vectors/`, `tb/minisoc_aes_ref_vectors.svh`):**
   - Desenvolvimento do modelo de referência em software [`scripts/gen_aes_ref_vectors.py`](../../scripts/gen_aes_ref_vectors.py) validado contra a norma NIST FIPS-197 (Apêndices B e C.1) e os vetores canônicos NIST SP 800-38A (F.1.1 ECB e F.2.1 CBC).
   - Geração automática dos arquivos de vetores para até 256 blocos:
     - [`tb/minisoc_aes_ref_vectors.svh`](../../tb/minisoc_aes_ref_vectors.svh) (incluído diretamente pelo testbench SystemVerilog)
     - [`tb/vectors/pt_256.hex`](../../tb/vectors/pt_256.hex), [`tb/vectors/ecb_ct_256.hex`](../../tb/vectors/ecb_ct_256.hex), [`tb/vectors/cbc_ct_256.hex`](../../tb/vectors/cbc_ct_256.hex) e [`tb/vectors/ctr_ct_256.hex`](../../tb/vectors/ctr_ct_256.hex)

4. **Testbench de Bloco com a Memória (`tb/tb_minisoc_aes_top.sv`, `verdicmd/verdi_w06.cmd`, `scripts/MakeFile`):**
   - Criação do testbench autoverificável [`tb_minisoc_aes_top.sv`](../../tb/tb_minisoc_aes_top.sv) integrando `minisoc_memory` e `minisoc_aes_top`, verificando:
     - Isolamento do multiplexador de posse da memória (`MEM_SEL_AES`).
     - Operações completas *in-place* de **Cifragem (`PT -> CT`)** seguidas de **Decriptação (`CT -> PT`)** para **1, 2 e 256 blocos** nos modos **ECB (`000`)**, **CBC (`001`)** e **CTR (`101`)**, comparando 100% das palavras na SRAM com o modelo de referência em Python.
     - Comportamento *sticky* de `DONE` e contagem exata de `BLOCKS_DONE` (`1`, `2` e `256`).
     - Detecção de configuração inválida (`NUM_BLOCKS = 0`, `257`, `32'hFFFF_FFFF`; modos reservados `110`, `111` e modos diferidos `010`, `011`, `100`) com asserção de `ERROR = 1`, preservação intacta da memória e recuperação limpa no próximo `START` válido.

---

## 2. Limitação Conhecida da Release v1.0 (Comunicação ao Verificador Parceiro)

> **[!IMPORTANT] Limitação Conhecida (v1.0 — Semana 6):**
> Conforme o cronograma do projeto, a versão v1.0 do `minisoc_aes_top` implementa os modos **ECB (`3'b000`)**, **CBC (`3'b001`)** e **CTR (`3'b101`)** em cifragem e decriptação.
> Os modos **PCBC (`3'b010`)**, **CFB (`3'b011`)** e **OFB (`3'b100`)** estão programados para a **Semana 10**. Na release v1.0 atual, a seleção de `MODE` igual a `010`, `011` ou `100` é tratada pelo validador de configuração juntamente com os modos reservados (`110`, `111`), sinalizando `ERROR = 1` e encerrando a operação sem modificar a memória.

---

## 3. Resultados da Simulação no Synopsys VCS (`tb_minisoc_aes_top.sv`)

A simulação no Synopsys VCS encerrou em `194201000 ps` (`194,201 µs`) com **0 erros e 60/60 verificações aprovadas (`OVERALL RESULT: PASS`)**:

| Caso de Teste | Modo / Configuração | Quantidade de Blocos | Escopo Verificado na SRAM (1024 $\times$ 32) | Resultado |
| :--- | :---: | :---: | :--- | :---: |
| **TEST 1 — Arbitragem de Memória** | `MEM_SEL_AES = 0/1` | 1 bloco (4 palavras) | Bloqueio de escrita externa quando `MEM_SEL_AES = 1` | **PASS (1/1)** |
| **TEST 2 — Modo ECB** | `MODE = 3'b000` (`ENC` + `DEC`) | **1, 2 e 256 blocos** | Cifragem *in-place* vs `REF_ECB_CT_BLOCKS` + Decriptação *in-place* vs `REF_PT_BLOCKS` + `DONE` *sticky* + `BLOCKS_DONE = 1, 2, 256` | **PASS (15/15)** |
| **TEST 3 — Modo CBC** | `MODE = 3'b001` (`ENC` + `DEC`) | **1, 2 e 256 blocos** | Cifragem *in-place* vs `REF_CBC_CT_BLOCKS` + Decriptação *in-place* vs `REF_PT_BLOCKS` + encadeamento de `IV` + `BLOCKS_DONE = 1, 2, 256` | **PASS (15/15)** |
| **TEST 4 — Modo CTR** | `MODE = 3'b101` (`ENC` + `DEC`) | **1, 2 e 256 blocos** | Cifragem *in-place* vs `REF_CTR_CT_BLOCKS` + Decriptação *in-place* vs `REF_PT_BLOCKS` (`IV ^ zero_ext(CTR++)`) + `BLOCKS_DONE = 1, 2, 256` | **PASS (15/15)** |
| **TEST 5 — Configurações Inválidas** | `NUM_BLOCKS = 0, 257, 0xFFFFFFFF`<br>`MODE = 110, 111, 010, 011, 100` | — | `ERROR = 1`, `BUSY = 0`, `DONE = 0`, `BLOCKS_DONE = 0` e bloco sentinela na SRAM preservado sem alteração | **PASS (9/9)** |
| **TEST 6 — Recuperação Pós-Erro** | `MODE = 3'b000`, `NUM_BLOCKS = 1` | 1 bloco | Limpeza de `ERROR = 0` e conclusão normal (`ENC` + `DEC`) no próximo `START` válido | **PASS (5/5)** |

**Comandos para execução no servidor Synopsys (VCS / Verdi):**

```bash
# 1. Executar lint (vlogan +lint=all) da Semana 6 e salvar lint_w06.log
make -f scripts/MakeFile lint_w06

# 2. Compilar e rodar a simulação do testbench de bloco da Semana 6
make -f scripts/MakeFile run_w06

# 3. Abrir as formas de onda no Verdi com os sinais da Semana 6
make -f scripts/MakeFile wave_w06
```
