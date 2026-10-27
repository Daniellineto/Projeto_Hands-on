# Relatório - Semana 02

## 1. O que foi feito
- Definição do diagrama de blocos arquitetural de topo e dos contratos das interfaces internas entre os módulos (`spi_core`, `cdc_sync`, `reset_sync`, `regbank`, `aes_core`, `mem_data_if`).
- Detalhamento do pinout das interfaces externas de topo (GLOBAL RESET, clk from OSC, SPI IF e MEMORY DATA IF).
- Mapeamento e especificação completa do banco de registradores de 32 bits (`CTRL`, `STATUS`, `PLL_CFG`, `MEM_CFG`, `BLOCK_LEN`, `KEY_0` a `KEY_3`).
- Definição da estratégia de Clock, Reset e CDC:
  - Domínio serial nativo em `SCLK` (shift register, contador e MISO) e domínio do sistema em `sys_clk`.
  - Travessia assíncrona baseada em *Toggle Synchronizers* com barramentos estáticos e protocolo de leitura SPI com *Dummy Byte* de 8 ciclos.
  - Comportamento autônomo do PLL mockado (travamento e asserção de `pll_locked`) com proteção contra *reset deadlock* no registrador `PLL_CFG` (resetado unicamente por `global_rst_n`).
  - Árvores de reset com liberação síncrona nos respectivos domínios (`pll_rst_n`, `sys_rst_n`, `spi_rst_n`).
- Especificação formal dos modelos comportamentais do PLL (`pll_mock`) e da memória SRAM (`sram_model`), definindo portas, parâmetros e semântica compatível com a trilha de Verificação (DV).
- Escolha e fundamentação da microarquitetura do acelerador AES (iterativa com datapath de 128 bits e 1 rodada por ciclo de relógio).
- Definição do contrato de portas do núcleo `aes_core`, permitindo o desenvolvimento e validação isolados em RTL prévios à integração com a interface SPI.
- Apresentação da arquitetura e das interfaces de topo com a trilha parceira de verificação.
- Elaboração, consolidação e compilação do Documento de Arquitetura formal em LaTeX (v1.0) para suporte à defesa técnica.

## 2. Resultados Obtidos
- Especificação arquitetural formal (v1.0) finalizada, congelada e documentada em LaTeX com geração do documento em PDF (`Arquitetura_V1.0.pdf`).
- Interfaces de fronteira e internas rigorosamente mapeadas, garantindo clareza e paridade com o ambiente de testes em UVM.
- Diagramas de blocos, árvore de reset e FSM do núcleo AES estabelecidos.
- Alinhamento de contratos concluído junto à trilha parceira de Design Verification.

## 3. Problemas Encontrados
- Nenhum impedimento técnico ou divergência de interface identificado durante o fechamento da arquitetura.

## 4. Próximos Passos
- Iniciar o desenvolvimento em RTL do núcleo `aes_core` na Semana 3 de forma autônoma.
- Criar o testbench dedicado (`tb_aes_core.sv`) utilizando os vetores oficiais de teste da norma NIST FIPS 197.
- Implementar o modelo comportamental de memória SRAM para validação das leituras e escritas de blocos de 128 bits.

## 5. Resumo das Decisões de Arquitetura
**Estratégia de Clock, Reset e CDC**
- Dois domínios de relógio assíncronos independentes (`SCLK` e `sys_clk`).
- Sincronização por *Toggle* com barramentos de dados estáveis, eliminando sobrecarga de FIFOs assíncronas.
- Leitura SPI com *Dummy Byte* (8 ciclos de relógio serial), garantindo tempo determinístico para travessia de CDC sem demandar estados de espera (*wait-states*).
- `PLL_CFG` imune a *deadlock*: conectado exclusivamente a `global_rst_n`, permitindo reprogramação dinâmica sem reset acidental dos registradores.

**Microarquitetura AES e Subsistema de Memória**
- Datapath nativo de 128 bits com execução iterativa de 1 rodada/ciclo (11 ciclos por bloco de 128 bits), garantindo equilíbrio entre área, taxa de transferência e complexidade de controle.
- FSM com suporte a operações de Encriptação e Decriptação (cálculo antecipado de chave na decifragem em 10 ciclos).
- Controlador `mem_data_if` como camada de adaptação e serialização de dados de 128 bits para a memória SRAM externa.
