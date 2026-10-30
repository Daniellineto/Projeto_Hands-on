# Relatório Semanal 02 — Desafio: SubBytes e ShiftRows

**Data de entrega:** 30/10/2026  
**Autor:** Daniel Lima Neto  

---

## 1. Resumo das Atividades Realizadas

1. **Reorganização do Repositório:**
   - Adequação da árvore de diretórios do repositório ao padrão especificado para o projeto integrador MiniSoC AES (`docs/`, `rtl/minisoc_aes/`, `rtl/minisoc_mem/`, `rtl/minisoc_pll/`, `rtl/minisoc_spi/`, `tb/`, `formal/`, `syn/`, `upf/` e `scripts/`).
   - Inclusão do documento de especificação oficial (`docs/spec/DV_BlockGuide_MiniSoCAES_v1.0.0.pdf`).

2. **Implementação RTL (`rtl/minisoc_aes/`):**
   - [`minisoc_aes_sbox.sv`](../../rtl/minisoc_aes/minisoc_aes_sbox.sv): S-Box puramente combinacional com entrada de 8 bits (`data_i`) e saída de 8 bits (`data_o`), implementando a tabela de substituição de 256 entradas da norma NIST FIPS-197 (Seção 5.1.1, Figura 7) com `unique case` completo.
   - [`minisoc_aes_sub_bytes.sv`](../../rtl/minisoc_aes/minisoc_aes_sub_bytes.sv): Transformação `SubBytes` puramente combinacional sobre o estado de 128 bits (`state_i` $\rightarrow$ `state_o`), instanciando 16 módulos `minisoc_aes_sbox` via bloco `generate`. Respeita a convenção de empacotamento onde o byte $n \in [0, 15]$ ocupa `state[127 - 8*n -: 8]` e corresponde a $s[r][c]$ com $r = n \bmod 4$ e $c = \lfloor n / 4 \rfloor$.
   - [`minisoc_aes_shift_rows.sv`](../../rtl/minisoc_aes/minisoc_aes_shift_rows.sv): Transformação `ShiftRows` puramente combinacional implementada exclusivamente por reordenação de fios (*wire reordering*), aplicando o deslocamento cíclico por linha $s'[r][c] = s[r][(c + r) \bmod 4]$ para $r \in \{0, 1, 2, 3\}$.

3. **Verificação e Testbench Autoverificável (`tb/tb_minisoc_aes_sub_shift.sv`):**
   - **Teste A (Exaustivo da S-Box):** Estímulo sequencial das 256 entradas (`8'h00` a `8'hFF`) no módulo `minisoc_aes_sbox`, comparando cada saída contra a tabela de referência da FIPS-197 (incluindo checagem explícita de `sbox(8'h00) = 8'h63` e `sbox(8'h53) = 8'hed`).
   - **Teste B (Cadeia `SubBytes` $\rightarrow$ `ShiftRows` no Apêndice B da FIPS-197):** Aplicação dos estados *"Start of Round"* de todas as **10 rodadas (Rodadas 1 a 10)** do exemplo oficial de cifragem da FIPS-197 (Apêndice B), verificando automaticamente a saída intermediária *"After SubBytes"* e a saída final *"After ShiftRows"*.
   - Automação via [`scripts/MakeFile`](../../scripts/MakeFile) permitindo compilação com `+lint=all` e execução em comando único.

---

## 2. Resultados dos Testes

| Caso de Teste | Escopo Avaliado | Vetores Testados | Resultado |
| :--- | :--- | :---: | :---: |
| **Lint (`vlogan +lint=all`)** | `minisoc_aes_sbox`, `minisoc_aes_sub_bytes`, `minisoc_aes_shift_rows`, `tb_minisoc_aes_sub_shift` | — | **0 erros / 0 warnings** |
| **Teste A — S-Box Exaustiva** | `minisoc_aes_sbox` (`8'h00`..`8'hFF`, incl. `0x00 -> 0x63` e `0x53 -> 0xed`) | 256 / 256 | **PASS** |
| **Teste B — FIPS-197 Apêndice B (Rodada 1)** | `193de3bea0f4e22b9ac68d2ae9f84808` $\rightarrow$ SubBytes (`d42711aee0bf98f1b8b45de51e415230`) $\rightarrow$ ShiftRows (`d4bf5d30e0b452aeb84111f11e2798e5`) | 1 / 1 | **PASS** |
| **Teste B — FIPS-197 Apêndice B (Rodada 10)** | `eb40f21e592e38848ba113e71bc342d2` $\rightarrow$ SubBytes (`e9098972cb31075f3d327d94af2e2cb5`) $\rightarrow$ ShiftRows (`e9317db5cb322c723d2e895faf090794`) | 1 / 1 | **PASS** |
| **Teste B — FIPS-197 Apêndice B (Rodadas 2 a 9)** | Cadeia completa *"Start of Round"* $\rightarrow$ *"After SubBytes"* $\rightarrow$ *"After ShiftRows"* nas demais rodadas | 8 / 8 | **PASS** |

**Comando único para execução:**
```bash
make -f scripts/MakeFile run
```

---

## 3. Leitura do Block Guide (Seções 1 a 3 e 8) — Dúvidas e Ambiguidades

Após a leitura técnica detalhada das **Seções 1 (Visão Geral)**, **2 (Arquitetura do Sistema)**, **3 (Interfaces de Topo)** e **8 (AES Engine)** do *Block Guide MiniSoC AES v1.0.0*, foram identificadas as seguintes dúvidas e ambiguidades para alinhamento com a equipe de especificação/verificação:

1. **Travessia de Domínio de Clock (CDC) entre Controle/SPI (`clk` = 2 GHz) e AES Engine (`sys_clk`):**
   - Na **Seção 2.2** e **Figura 1**, o bloco SPI opera no clock de referência *always-on* (`clk` de 2 GHz), enquanto o AES Engine opera em `sys_clk` (dividido por `/1`, `/2`, `/4` ou `/8`, podendo operar a 250 MHz).
   - **Dúvida:** O comando `START` (definido na Seção 6.1 como *write-one-pulse*) é gerado no domínio de 2 GHz. Quando `sys_clk` estiver configurado em `/2`, `/4` ou `/8`, um pulso de 1 ciclo de `clk` terá duração menor que 1 período de `sys_clk`. Qual módulo (`minisoc_spi`, `minisoc_top` ou `minisoc_aes_top`) é responsável pelo sincronizador de pulso/toggle CDC para `START` e para os sinais de retorno `BUSY`, `DONE`, `ERROR` e `BLOCKS_DONE`?

2. **Estado de `spi_miso` quando `spi_cs_n = 1` (Inativo) e durante Write/Read Request (Seção 3):**
   - Na tabela da **Seção 3**, `spi_miso` é listado como saída de 1 bit do topo.
   - **Dúvida:** Quando `spi_cs_n = 1` (escravo deselecionado) ou durante o envio da primeira transação de leitura (Read Request) e nos 8 bits iniciais da fase de retorno (`NOP`), o pino `spi_miso` deve ser mantido em nível lógico baixo (`1'b0`) ou em alta impedância (`1'bz`)?

3. **Visibilidade de `mem_o_data` quando `MEM_SEL_AES = 1` (Seções 2 e 3):**
   - Na **Seção 3**, a porta de saída `mem_o_data[31:0]` expõe o dado lido da memória compartilhada para a interface externa `MEMORY DATA`.
   - **Dúvida:** Enquanto a memória estiver sob posse do AES Engine (`MEM_SEL_AES = 1`), `mem_o_data` deve continuar refletindo diretamente o barramento `rdata` da SRAM (expondo externamente as palavras intermediárias lidas pelo AES) ou deve ser isolado/grampeado em `32'h0` quando `MEM_SEL_AES = 1`?

4. **Inicialização do Encadeamento no Modo PCBC (`MODE = 3'b010` — Seção 8.2):**
   - A **Seção 8.2** define o modo PCBC como *"Encadeamento propagado com entrada/saída do bloco anterior"*.
   - **Dúvida:** Confirma-se a definição clássica onde, para o primeiro bloco ($i = 0$), o vetor de encadeamento inicial é exclusivamente `IV` ($C_0 = E_K(P_0 \oplus IV)$ na cifragem; $P_0 = D_K(C_0) \oplus IV$ na decifragem), e para os blocos subsequentes ($i \ge 1$) utiliza-se $P_{i-1} \oplus C_{i-1}$?

5. **Largura de Realimentação e Papel do Bit `DECRYPT` nos Modos CFB, OFB e CTR (Seções 8.1 e 8.2):**
   - A **Seção 8.2** especifica que CFB (`011`), OFB (`100`) e CTR (`101`) utilizam sempre o *primitive* de *encrypt* do datapath.
   - **Dúvidas:**
     - No modo **CFB**, confirma-se que a operação é **CFB-128** (bloco completo de 128 bits por iteração), onde o bit `DECRYPT` apenas seleciona quem alimenta o registrador de encadeamento do próximo bloco (o bloco cifrado produzido $C_i$ quando `DECRYPT = 0`, ou o bloco de entrada lido da memória $C_i$ quando `DECRYPT = 1`)?
     - Nos modos **OFB** e **CTR**, em que cifragem e decifragem são matematicamente idênticas, o valor escrito no bit `DECRYPT` deve ser completamente ignorado pelo hardware?

6. **Alinhamento do Contador de 64 bits com o `IV` de 128 bits no Modo CTR (`MODE = 3'b101` — Seção 8.2):**
   - A **Seção 8.2** especifica que o modo CTR *"Usa AES encrypt sobre IV XOR contador de 64 bits zero-extendido; contador é incrementado por bloco"*.
   - **Dúvida:** A extensão com zeros para 128 bits posiciona o contador nos 64 bits menos significativos (`IV ^ {64'h0, (cfg_counter + block_idx)}`)? Caso a soma `cfg_counter + block_idx` ultrapasse `64'hFFFF_FFFF_FFFF_FFFF`, o incremento sofre *wrap-around* em 64 bits antes do XOR com `IV` ou propaga *carry* para os 64 bits superiores?

7. **Comportamento de `DONE` e `BLOCKS_DONE` em Condição de `ERROR` e de `START` concorrente (Seções 8.2 a 8.4):**
   - Na **Seção 8.2**, configurações fora do intervalo válido (`NUM_BLOCKS` $\notin [1, 256]$ ou `MODE` $\in \{3'b110, 3'b111\}$) *"produzem ERROR e encerram a operação sem processamento normal"*.
   - **Dúvidas:**
     - Quando uma operação é abortada por `ERROR = 1`, o bit `DONE` deve permanecer em `0` ou também deve ser elevado a `1` para indicar término da tentativa?
     - O contador `BLOCKS_DONE` é zerado no momento do `START` com erro ou preserva o valor da operação anterior?
     - Caso o software envie um novo pulso `START = 1` enquanto `BUSY = 1`, o hardware deve ignorar o comando ou sinalizar erro?
