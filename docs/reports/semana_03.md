# Relatório Semanal 03 — Microarquitetura e Transformações de Rodada

**Data de entrega:** 06/11/2026  
**Autor:** Daniel Lima Neto  

---

## 1. Resumo das Atividades Realizadas

1. **Documento de Microarquitetura v1.0 (`docs/architecture/`):**
   - Elaboração do documento técnico curto em LaTeX ([`docs/architecture/latex/main.tex`](../architecture/latex/main.tex)) e compilação para PDF ([`docs/architecture/latex/main.pdf`](../architecture/latex/main.pdf)), definindo:
     - **Diagrama de Blocos Interno (`minisoc_top`):** Interconexão entre `minisoc_spi`, `minisoc_pll_mock`, `minisoc_aes_top` e `minisoc_memory`, incluindo o multiplexador de posse da memória SRAM *single-port* controlado por `SYSTEM_CONTROL.MEM_SEL_AES`.
     - **Microarquitetura do AES (`minisoc_aes_dp` e `minisoc_aes_key_exp`):** Adoção da arquitetura **iterativa de 128 bits com 1 rodada por ciclo** (10 ciclos por bloco) e **expansão de chave pré-calculada** (armazenando as 11 subchaves `round_key[0..10]` em 10 ciclos no início da transação). Justificativa técnica baseada no gargalo de I/O da SRAM de 32 bits (4 ciclos de leitura + 4 ciclos de escrita por bloco), na dependência sequencial entre blocos dos modos encadeados (`CBC`, `PCBC`, `CFB`, `OFB`) e na necessidade de subchaves em ordem reversa ($K_{10} \rightarrow K_0$) na decriptação dos modos `ECB`, `CBC` e `PCBC`.
     - **FSM do `minisoc_aes_top`:** Máquina de estados síncrona a `sys_clk` composta pelos estados `IDLE`, `VALIDATE`, `ERROR`, `KEY_EXP`, `RD_W0..W3`, `PROCESS_DP`, `WR_W0..W3`, `CHECK_NEXT` e `FINISH`, resultando em $12 + 19N$ ciclos de `sys_clk` para um lote de $N$ blocos.
     - **Estratégia de CDC (`spi_sclk` $\rightarrow$ `clk`, Seção 5.3 do Block Guide):** Sincronização de evento por *toggle* (`T-FF`) no 40º bit do frame SPI seguida por sincronizador de 2 flip-flops + detector de borda XOR (`FF2 ^ FF3`) no domínio `clk` (2 GHz), amostrando o registrador estático `rx_frame_captured[39:0]`.
     - **Sequência de Reset do Domínio do Sistema (`sys_clk`, Seção 4.2 do Block Guide):** Topologia *Asynchronous Assert, Synchronous Deassert* (AADS) de 2 flip-flops condicionada por `rst_n & pll_locked`, mantendo o domínio `sys_clk` em reset enquanto o PLL não estiver travado e liberando `sys_rst_n` sincronamente após duas bordas de subida de `sys_clk`.

2. **Implementação RTL das Transformações Diretas (`rtl/minisoc_aes/`):**
   - [`minisoc_aes_mix_columns.sv`](../../rtl/minisoc_aes/minisoc_aes_mix_columns.sv): Transformação `MixColumns` puramente combinacional sobre as 4 colunas de 32 bits do estado de 128 bits, operando no corpo de Galois $GF(2^8)$ com polinômio irredutível $m(x) = x^8 + x^4 + x^3 + x + 1$ (`8'h1b`) por meio da função `xtime` (coeficientes `{02, 03, 01, 01}`).
   - [`minisoc_aes_add_round_key.sv`](../../rtl/minisoc_aes/minisoc_aes_add_round_key.sv): Transformação `AddRoundKey` puramente combinacional via operação XOR bit a bit de 128 bits (`state_o = state_i ^ round_key_i`).
   - Integração com os módulos da Semana 2: [`minisoc_aes_sbox.sv`](../../rtl/minisoc_aes/minisoc_aes_sbox.sv), [`minisoc_aes_sub_bytes.sv`](../../rtl/minisoc_aes/minisoc_aes_sub_bytes.sv) e [`minisoc_aes_shift_rows.sv`](../../rtl/minisoc_aes/minisoc_aes_shift_rows.sv).

3. **Implementação RTL das Transformações Inversas (`rtl/minisoc_aes/`):**
   - [`minisoc_aes_inv_sbox.sv`](../../rtl/minisoc_aes/minisoc_aes_inv_sbox.sv): S-Box inversa combinacional de 256 entradas conforme a Figura 14 da norma NIST FIPS-197 (Seção 5.3.2).
   - [`minisoc_aes_inv_sub_bytes.sv`](../../rtl/minisoc_aes/minisoc_aes_inv_sub_bytes.sv): Transformação `InvSubBytes` sobre o estado de 128 bits instanciando 16 módulos `minisoc_aes_inv_sbox` em paralelo via bloco `generate`.
   - [`minisoc_aes_inv_shift_rows.sv`](../../rtl/minisoc_aes/minisoc_aes_inv_shift_rows.sv): Transformação `InvShiftRows` puramente combinacional por reordenação de fios, deslocando ciclicamente a linha $r \in \{0, 1, 2, 3\}$ em $r$ posições para a direita ($s'[r][c] = s[r][(c - r) \bmod 4]$).
   - [`minisoc_aes_inv_mix_columns.sv`](../../rtl/minisoc_aes/minisoc_aes_inv_mix_columns.sv): Transformação `InvMixColumns` combinacional em $GF(2^8)$ multiplicando cada coluna pela matriz inversa de coeficientes `{0e, 0b, 0d, 09}` construídos por encadeamento de `xtime` (`x2`, `x4`, `x8`).

4. **Testes Unitários Autoverificáveis e Scripts (`tb/`, `scripts/`, `syn/`):**
   - [`tb_minisoc_aes_sub_shift.sv`](../../tb/tb_minisoc_aes_sub_shift.sv): Atualizado para verificar todas as 9 unidades combinacionais (diretas e inversas) contra os vetores intermediários da FIPS-197 (Apêndice B e Apêndice C.1).
   - [`scripts/MakeFile`](../../scripts/MakeFile) e [`syn/synth_file.tcl`](../../syn/synth_file.tcl): Atualizados com os 9 módulos de transformação de rodada e suporte à abertura automática de ondas no Verdi (`verdicmd/verdi.cmd`).

---

## 2. Resultados dos Testes Unitários

| Caso de Teste | Escopo Avaliado | Vetores / Rodadas Testadas | Resultado |
| :--- | :--- | :---: | :---: |
| **Lint (`vlogan +lint=all`)** | Todos os 9 módulos RTL (`rtl/minisoc_aes/*.sv`) + `tb_minisoc_aes_sub_shift.sv` | — | **0 erros / 0 warnings** |
| **TEST 1 — S-Box e InvS-Box Exaustivas** | `minisoc_aes_sbox` e `minisoc_aes_inv_sbox` (`8'h00`..`8'hFF` + identidade bijetora `inv_sbox(sbox(x)) == x`) | 256 / 256 (cada) | **PASS** |
| **TEST 2 — FIPS-197 Apêndice B (Cifragem)** | `SubBytes` $\rightarrow$ `ShiftRows` $\rightarrow$ `MixColumns` $\rightarrow$ `AddRoundKey` em todas as rodadas (Ciphertext final: `3925841d02dc09fbdc118597196a0b32`) | 10 / 10 rodadas | **PASS** |
| **TEST 3 — FIPS-197 Apêndice B (Reverso)** | `InvMixColumns`, `AddRoundKey`, `InvSubBytes` e `InvShiftRows` revertendo cada etapa das rodadas 10 a 1 | 10 / 10 rodadas | **PASS** |
| **TEST 4 — FIPS-197 Apêndice C.1 (Inverse Cipher)** | Estados intermediários `istart`, `is_row`, `is_box`, `ik_add`, `im_col` (Rodadas 1 e 10) e recuperação completa do plaintext (`00112233445566778899aabbccddeeff`) | 10 / 10 rodadas | **PASS** |

**Comandos de execução:**
```bash
# Compilar com lint e executar simulação autoverificável
make -f scripts/MakeFile run

# Abrir ondas no Synopsys Verdi com sinais pré-carregados
make -f scripts/MakeFile wave
```

---

## 3. Pontos Alinhados para a Defesa da Microarquitetura

1. **Particionamento Direto vs. Inverso no Datapath:**
   - Modos **ECB (`000`), CBC (`001`) e PCBC (`010`)**: utilizam o caminho direto (`SubBytes` $\rightarrow$ `ShiftRows` $\rightarrow$ `MixColumns` $\rightarrow$ `AddRoundKey`) quando `DECRYPT = 0` e o caminho inverso (`InvShiftRows` $\rightarrow$ `InvSubBytes` $\rightarrow$ `AddRoundKey` $\rightarrow$ `InvMixColumns`) quando `DECRYPT = 1`.
   - Modos **CFB (`011`), OFB (`100`) e CTR (`101`)**: utilizam sempre o caminho direto (*Cipher*) tanto na cifragem quanto na decifragem, aplicando XOR entre a saída cifrada do datapath e o bloco de dados lido da memória.
2. **Desvio de `MixColumns` / `InvMixColumns` na 10ª Rodada:**
   - Tanto no *Cipher* quanto no *Inverse Cipher*, a 10ª rodada omite a etapa de mistura de colunas via multiplexador controlado por `round == 4'd10`.
3. **Reuso de `AddRoundKey`:**
   - Como a adição e a subtração em $GF(2^8)$ correspondem à mesma operação XOR bit a bit, o módulo `minisoc_aes_add_round_key` é idêntico nos fluxos direto e inverso.
