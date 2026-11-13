# Relatório Semanal 04 — Expansão de Chave e Datapath AES-128

**Data de entrega:** 13/11/2026  
**Autor:** Daniel Lima Neto  

---

## 1. Resumo das Atividades Realizadas

1. **Implementação da Expansão de Chave (`rtl/minisoc_aes/minisoc_aes_key_exp.sv`):**
   - Desenvolvimento do módulo [`minisoc_aes_key_exp.sv`](../../rtl/minisoc_aes/minisoc_aes_key_exp.sv) segundo a norma NIST FIPS-197 (Seção 5.2), adotando a estratégia **pré-computada** com armazenamento das 11 chaves de rodada (`round_keys_q[0:10]`, de 128 bits cada).
   - Ao receber o pulso `start_i`, o módulo registra a chave inicial $K_0 = \texttt{key\_i}$ no índice `0` e calcula iterativamente as subchaves $K_1 \dots K_{10}$ ao longo de **10 ciclos de clock** (`round_cnt_q = 1..10`), utilizando a função $g(w_3) = \text{SubWord}(\text{RotWord}(w_3)) \oplus \text{Rcon}[r]$ com 4 instâncias em paralelo de [`minisoc_aes_sbox.sv`](../../rtl/minisoc_aes/minisoc_aes_sbox.sv).
   - Disponibiliza leitura combinacional de latência zero (`round_key_o = round_keys_q[round_sel_i]`), permitindo que o datapath acesse $K_0 \rightarrow K_{10}$ na cifragem e $K_{10} \rightarrow K_0$ na decriptação sem recalcular chaves a cada bloco.

2. **Implementação do Datapath Iterativo AES-128 (`rtl/minisoc_aes/minisoc_aes_dp.sv`):**
   - Desenvolvimento do módulo [`minisoc_aes_dp.sv`](../../rtl/minisoc_aes/minisoc_aes_dp.sv) com arquitetura **iterativa de 128 bits (1 rodada por ciclo)** e suporte bidirecional controlado por `decrypt_i` (`0` = *Cipher*, `1` = *Inverse Cipher*).
   - Interface de controle síncrona (`start_i`, `busy_o`, `done_o`) e seleção automática do índice da subchave (`round_sel_o[3:0]`):
     - **Ciclo de Disparo (`start_i = 1`):** Seleciona $K_0$ (cifragem) ou $K_{10}$ (decriptação), executa o `AddRoundKey` inicial (`block_i ^ round_key_i`) e armazena o resultado no registrador de estado `state_q[127:0]`.
     - **Rodadas 1 a 10 (`round_q = 1..10`, 10 ciclos):**
       - **Cifragem (`decrypt_q = 0`):** `SubBytes` $\rightarrow$ `ShiftRows` $\rightarrow$ `MixColumns` (desviado via multiplexador quando `round_q == 10`) $\rightarrow$ `AddRoundKey` com $K_{\text{round\_q}}$.
       - **Decriptação (`decrypt_q = 1`):** `InvShiftRows` $\rightarrow$ `InvSubBytes` $\rightarrow$ `AddRoundKey` com $K_{10 - \text{round\_q}}$ $\rightarrow$ `InvMixColumns` (desviado via multiplexador quando `round_q == 10`).
     - **Conclusão:** Ao fim do 10º ciclo, `state_q` contém o bloco final (`block_o`), desativando `busy_o = 0` e elevando `done_o = 1`.

3. **Testbench Autoverificável e Scripts (`tb/tb_minisoc_aes_dp.sv`, `scripts/MakeFile`, `verdicmd/`):**
   - Criação do testbench [`tb_minisoc_aes_dp.sv`](../../tb/tb_minisoc_aes_dp.sv) integrando `minisoc_aes_key_exp` e `minisoc_aes_dp`, verificando automaticamente as 11 subchaves expandidas, a cifragem (`PT -> CT`) e a decriptação (`CT -> PT`) para os vetores dos **Apêndices C.1 e B** da FIPS-197.
   - Parametrização do [`scripts/MakeFile`](../../scripts/MakeFile) com alvos dedicados para Semana 3 (`run_w03`, `wave_w03`) e Semana 4 (`run_w04`, `wave_w04`), acompanhados dos scripts [`verdicmd/verdi_w03.cmd`](../../verdicmd/verdi_w03.cmd) e [`verdicmd/verdi_w04.cmd`](../../verdicmd/verdi_w04.cmd).

---

## 2. Justificativa Técnica: Expansão de Chave Pré-Computada vs. *On-the-Fly*

| Critério | Expansão *On-the-Fly* | Expansão Pré-Computada (Adotada) |
| :--- | :--- | :--- |
| **Armazenamento (Registradores)** | $1 \times 128\text{ bits}$ (apenas chave atual) | $11 \times 128\text{ bits} = 1408\text{ FFs}$ (`round_keys_q[0:10]`) |
| **Suporte à Decriptação ($K_{10} \rightarrow K_0$)** | Exige pré-cálculo de $K_{10}$ a cada bloco **ou** circuito extra de expansão inversa (*Inverse Key Schedule*) | **Imediato:** basta indexar `round_sel_o = 10 - round_q` sobre o banco já calculado |
| **Latência em Lotes Multi-Bloco ($N \le 256$)** | Recalcula subchaves em todos os $N$ blocos | Calcula **uma única vez** (10 ciclos no início do lote) e amortiza em até 256 blocos |
| **Complexidade de Controle / Verificação** | Acoplamento rígido ciclo a ciclo com o datapath | Desacoplado: leitura combinacional pura por índice `round_sel_i[3:0]` |

---

## 3. Resultados dos Testes

| Caso de Teste | Vetor de Referência (FIPS-197) | Escopo Verificado | Resultado |
| :--- | :--- | :---: | :---: |
| **Lint (`vlogan +lint=all`)** | Todos os módulos RTL (`minisoc_aes_*.sv`) + `tb_minisoc_aes_dp.sv` | — | **0 erros / 0 warnings** |
| **TEST 1A — Expansão de Chave (Apêndice C.1)** | `key = 000102030405060708090a0b0c0d0e0f` | Subchaves `K0` a `K10` (11/11) | **PASS** |
| **TEST 1B — Cifragem (Apêndice C.1)** | `pt = 00112233445566778899aabbccddeeff` $\rightarrow$ `ct = 69c4e0d86a7b0430d8cdb78070b4c55a` | 10 rodadas diretas | **PASS** |
| **TEST 1C — Decriptação (Apêndice C.1)** | `ct = 69c4e0d86a7b0430d8cdb78070b4c55a` $\rightarrow$ `pt = 00112233445566778899aabbccddeeff` | 10 rodadas inversas | **PASS** |
| **TEST 2A — Expansão de Chave (Apêndice B)** | `key = 2b7e151628aed2a6abf7158809cf4f3c` | Subchaves `K0` a `K10` (11/11) | **PASS** |
| **TEST 2B — Cifragem (Apêndice B)** | `pt = 3243f6a8885a308d313198a2e0370734` $\rightarrow$ `ct = 3925841d02dc09fbdc118597196a0b32` | 10 rodadas diretas | **PASS** |
| **TEST 2C — Decriptação (Apêndice B)** | `ct = 3925841d02dc09fbdc118597196a0b32` $\rightarrow$ `pt = 3243f6a8885a308d313198a2e0370734` | 10 rodadas inversas | **PASS** |

**Comandos de execução:**
```bash
# Executar simulação da Semana 4 (Expansão de Chave + Datapath AES-128)
make -f scripts/MakeFile run_w04

# Abrir ondas da Semana 4 no Synopsys Verdi com sinais pré-carregados
make -f scripts/MakeFile wave_w04
```

