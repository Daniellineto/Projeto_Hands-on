# Estudo: Protocolo SPI (Serial Peripheral Interface)

## 1. Arquitetura e Conceito do SPI

* **Definição:** A **Serial Peripheral Interface (SPI)** é uma interface síncrona e *full-duplex* amplamente utilizada para interconectar microcontroladores a circuitos integrados periféricos (como sensores, ADCs, DACs, SRAM e registradores de deslocamento).
* **Modelo Main-Subnode:** A comunicação baseia-se na arquitetura de um único dispositivo principal (*main*) e um ou mais subnós (*subnodes*).
* **Desempenho:** Suporta frequências de *clock* significativamente mais elevadas em comparação com outras interfaces seriais, como o I2C. O padrão foca na topologia popular de **4 fios**.

---

## 2. Descrição dos 4 Sinais Lógicos

A interface de 4 fios utiliza as seguintes linhas de sinal:

1. **SCLK (Serial Clock):** Sinal de *clock* gerado exclusivamente pelo dispositivo *main* para sincronizar a transferência de dados entre o *main* e o *subnode*.
2. **CS (Chip Select):** Sinal emitido pelo *main* para selecionar o subnó desejado. Geralmente é um sinal **ativo em nível lógico baixo** (*active low*, `0`). Para desconectar o subnó do barramento, a linha CS é elevada para nível alto (`1`).
3. **MOSI / SDI (Main Out, Subnode In / Serial Data In):** Linha de dados que transmite informações do dispositivo *main* em direção ao *subnode*.
4. **MISO / SDO (Main In, Subnode Out / Serial Data Out):** Linha de dados que transmite informações do *subnode* para o dispositivo *main*.

---

## 3. Dinâmica da Transmissão de Dados

* **Inicialização:** A comunicação começa quando o dispositivo *main* envia o sinal de *clock* e habilita o *subnode* colocando a linha CS em nível lógico `0`.
* **Operação Full-Duplex Simultânea:** Durante a comunicação, os dados são transmitidos (deslocados serialmente para o barramento MOSI/SDO) e recebidos (amostrados/lidos a partir do barramento MISO/SDI) **ao mesmo tempo**.
* **Sincronização:** As bordas do sinal de *clock* orientam exatamente quando os dados devem ser deslocados e quando devem ser lidos.

---

## 4. Polaridade e Fase do Clock (CPOL e CPHA) e os 4 Modos SPI

O dispositivo *main* precisa configurar a polaridade e a fase do *clock* de acordo com as especificações do *subnode*:

* **CPOL (Clock Polarity):** Define o estado de repouso/ocioso do *clock* quando o CS está em nível alto:
  * `CPOL = 0`: O estado ocioso do *clock* é **nível lógico baixo (`0`)**.
  * `CPOL = 1`: O estado ocioso do *clock* é **nível lógico alto (`1`)**.
* **CPHA (Clock Phase):** Define qual borda do *clock* (subida ou descida) é utilizada para **amostrar** (*sample*) e qual é usada para **deslocar** (*shift*) os dados.

### Tabela dos 4 Modos SPI

| Modo SPI   | CPOL | CPHA | Estado Ocioso do Clock   | Borda de Amostragem (*Sampling*)  | Borda de Deslocamento (*Shifting*) |
| ---------- | ---- | ---- | ------------------------ | --------------------------------- | ---------------------------------- |
| **Modo 0** | 0    | 0    | Nível lógico baixo (`0`) | Borda de subida (*Rising edge*)   | Borda de descida (*Falling edge*)  |
| **Modo 1** | 0    | 1    | Nível lógico baixo (`0`) | Borda de descida (*Falling edge*) | Borda de subida (*Rising edge*)    |
| **Modo 2** | 1    | 0    | Nível lógico alto (`1`)  | Borda de descida (*Falling edge*) | Borda de subida (*Rising edge*)    |
| **Modo 3** | 1    | 1    | Nível lógico alto (`1`)  | Borda de subida (*Rising edge*)   | Borda de descida (*Falling edge*)  |

---

## 5. Topologias para Múltiplos Subnós (Multi-Subnode Configurations)

Quando um dispositivo principal (*main*) precisa se comunicar com mais de um periférico (*subnode*), o barramento SPI pode ser organizado de duas formas distintas:

### A. Modo Regular (Regular SPI Mode)

* **Conexão dos Sinais:** As linhas de *clock* (SCLK) e dados (MOSI e MISO) são compartilhadas em paralelo por todos os subnós, mas o *main* fornece uma **linha de Chip Select (CS) individual e dedicada** para cada subnó.
* **Controle de Comunicação:** Quando o *main* ativa a linha CS de um periférico específico (nível lógico baixo), as linhas de dados ficam ativas apenas para aquele componente.
* **Risco de Corrupção de Dados:** Se mais de um sinal CS for ativado simultaneamente, haverá colisão na linha MISO, resultando em corrupção de dados, pois o *main* não consegue identificar a origem das transmissões.
* **Limitação de Hardware:** A grande desvantagem do modo regular é o esgotamento de pinos do microcontrolador: a quantidade de GPIOs exigida cresce linearmente a cada novo periférico adicionado. Uma alternativa parcial é utilizar um multiplexador/decodificador externo para expandir os sinais CS.

### B. Modo Encadeado (Daisy-Chain Method)

* **Conexão dos Sinais:** Todos os subnós compartilham a **mesma linha de Chip Select (CS)** e o mesmo sinal de *clock* (SCLK) simultaneamente.
* **Propagação Sequencial de Dados:** Os dados trafegam de forma contínua através da cadeia: a saída MOSI do *main* conecta-se à entrada SDI do primeiro subnó; a saída SDO do primeiro subnó liga-se à entrada SDI do segundo, e assim por diante, até que o SDO do último subnó retorne para a linha MISO do *main*.
* **Sobrecarga de Ciclos de Clock:** O número de pulsos de *clock* necessários para transmitir uma informação é proporcional à posição do dispositivo na cadeia. Por exemplo, em um sistema de 8 bits com 3 subnós, são necessários **24 pulsos de clock** para que o dado atinja o terceiro subnó (contra apenas 8 pulsos no modo regular).
* **Requisito de Compatibilidade:** O modo *daisy-chain* exige suporte específico no hardware do periférico (consultar o *datasheet*).

---

## 6. Estudo de Caso e Otimização de Hardware: Chaves e Multiplexadores SPI

Substituir comutadores paralelos tradicionais por chaves controladas por SPI reduz drasticamente a complexidade de placas eletrônicas.

### 6.1 O Problema das Chaves Paralelas Tradicionais (ex: ADG1412)

* O comutador quad SPST tradicional **ADG1412** exige 4 linhas GPIO dedicadas do microcontrolador para controlar cada uma de suas quatro chaves.
* Em matrizes de comutação (como um sistema de teste com matriz *cross-point* 4×4 usando quatro ADG1412s), seriam necessários **16 GPIOs** apenas para controlar os interruptores, esgotando a capacidade do microcontrolador.
* **Uso de Conversores Serial-para-Paralelo:** Embora seja possível expandir os pinos com conversores externos, essa abordagem aumenta o custo do sistema e o número de componentes na lista de materiais (*BOM*).

### 6.2 A Solução com Chaves Controladas por SPI (ex: ADGS1412)

A nova geração de comutadores da Analog Devices integra uma interface SPI interna para controle digital:

1. **Economia no Modo Regular:** Ao conectar quatro chaves **ADGS1412** em modo regular, o consumo de pinos no microcontrolador cai de **16 para apenas 7 GPIOs** (3 linhas do barramento SPI + 4 linhas de CS individuais).
2. **Máxima Eficiência no Modo Daisy-Chain:** Ao encadear as chaves ADGS1412 em *daisy-chain*, são necessários **apenas 4 GPIOs no total** (CS, SCLK, MOSI e MISO) no microcontrolador, independentemente de quantas chaves forem adicionadas ao sistema.
3. **Configuração Daisy-Chain Extrema:** O *datasheet* do componente ADGS1412 recomenda a inclusão de um **resistor de pull-up no pino SDO** para garantir a integridade dos sinais de saída durante a propagação de dados entre os subnós.

### 6.3 Redução de Espaço em Placa (PCB)

* **Economia de Área:** Em sistemas de alta densidade de canais (como uma matriz *cross-point* 4×8 composta por oito chaves quad SPST em uma placa de 6 camadas), a adoção das chaves SPI da Analog Devices proporciona uma **redução de 20% no espaço total da PCB**.
* **Escalabilidade:** Conforme o número de chaves no sistema aumenta, o benefício da simplificação do roteamento e da redução da área ocupada torna-se exponencialmente mais relevante.

---

## 7. Referências Técnicas Citadas

O documento fundamenta-se nas seguintes publicações oficiais da Analog Devices:

1. **ADuCM3029 Data Sheet** (Analog Devices, Inc., Março de 2017).
2. **Nugent, Stephen.** *"Precision SPI Switch Configuration Increases Channel Density"*, publicado em *Analog Dialogue*, Maio de 2017.
3. **Usach, Miguel.** *AN-1248 Application Note: SPI Interface*, publicado por Analog Devices, Inc., Setembro de 2015.

---

## 8. Autoria

* **Autora:** Piyu Dhaker, Engenheira de Aplicações do *North America Central Applications Group* na Analog Devices.
* **Formação:** Mestre em Engenharia Elétrica pela *San Jose State University* (2007), com experiência prévia nas divisões de *Automotive Power Train* e *Power Management* da ADI.
