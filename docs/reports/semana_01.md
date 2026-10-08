# Relatório - Semana 01

## 1. O que foi feito
- Preparação do repositório estruturado.
- Criação do backlog inicial do projeto.
- Execução do ambiente com um exemplo mínimo (`dummy_aes.sv`).
- Estudo sobre os modos de operação do AES e protocolo SPI.

## 2. Resultados Obtidos
- Ambiente executando compilação, lint e simulação perfeitamente através do Makefile.
- Repositório base estruturado.

## 3. Problemas Encontrados
- Nenhum problema de infraestrutura encontrado até o momento.

## 4. Próximos Passos
- Iniciar a especificação e arquitetura na semana 2.
- Desenvolver blocos iniciais do RTL de acordo com a especificação funcional.

## 5. Resumo de Estudo (AES e SPI)
**AES (Advanced Encryption Standard)**
- Baseado em substituição e permutação (Rijndael).
- Blocos de 128 bits e chaves de 128, 192 ou 256 bits.
- Requer várias rodadas de transformações (SubBytes, ShiftRows, MixColumns, AddRoundKey).

**SPI (Serial Peripheral Interface)**
- Protocolo de comunicação síncrono serial (Master-Slave).
- Modos baseados em Polaridade de Clock (CPOL) e Fase de Clock (CPHA) definem a borda de amostragem.
- Linhas comuns: SCLK, MOSI, MISO, CS.
