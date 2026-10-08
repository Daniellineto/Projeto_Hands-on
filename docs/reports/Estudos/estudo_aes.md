# Estudo: Algoritmo AES (FIPS PUB 197)

## Capítulo 1: Introdução

O Capítulo 1 estabelece formalmente o propósito e o escopo da norma FIPS PUB 197:

- **Algoritmo Base**: Especifica o algoritmo Rijndael como a cifra de bloco simétrica oficial para o padrão AES.
- **Tamanhos de Bloco e Chave**: O padrão determina que o AES opera em blocos de dados de 128 bits e suporta três tamanhos de chave criptográfica: 128, 192 e 256 bits (referidos como AES-128, AES-192 e AES-256). Embora o algoritmo Rijndael original previsse tamanhos adicionais de bloco e chave, o padrão adotou apenas essas especificações.
- **Estrutura do Documento**: Apresenta o roteiro das seções seguintes da publicação, cobrindo definições, convenções de notação, matemática de corpos finitos, a especificação formal das rodadas de criptografia/descriptografia e considerações de implementação.

## Capítulo 2: Definições

O Capítulo 2 padroniza o vocabulário técnico, os parâmetros fundamentais e os operadores matemáticos que regem o algoritmo. Ele é dividido em duas partes:

### 2.1 Glossário de Termos e Acrônimos

Define os componentes estruturais essenciais do sistema:
- **AES (Advanced Encryption Standard)**: O padrão oficial de criptografia para proteção de dados eletrônicos.
- **Bloco (Block)**: Sequência de bits binários que compõem os dados de entrada, saída, o State e as chaves de rodada.
- **Estado (State)**: A matriz bidimensional retangular de bytes (com 4 linhas e $N_b$ colunas) que armazena os resultados intermediários durante a execução do algoritmo.
- **Chave de Cifra (Cipher Key)**: A chave secreta de entrada, representada como uma matriz com 4 linhas e $N_k$ colunas de bytes.
- **Chave de Rodada (Round Key)**: Subchaves derivadas da chave principal através do processo de expansão de chave, aplicadas diretamente ao State.
- **S-box**: Tabela de substituição não linear usada nas etapas de transformação de bytes e na rotina de chave.
- **Palavra (Word)**: Grupo de 32 bits (4 bytes) tratado como uma unidade única.
- **Transformação Afim (Affine Transformation)**: Operação que combina a multiplicação por uma matriz com a adição de um vetor.

### 2.2 Parâmetros do Algoritmo, Símbolos e Funções

Estabelece a notação formal e as rotinas operacionais:
- **$N_b$**: Número de colunas (palavras de 32 bits) do State. No AES, é estritamente fixado em $N_b = 4$ (128 bits).
- **$N_k$**: Número de palavras de 32 bits que compõem a chave de cifra ($N_k = 4, 6\text{ ou } 8$).
- **$N_r$**: Número de rodadas de transformação ($N_r = 10, 12\text{ ou } 14$, variando conforme $N_k$).
- **Transformações do Algoritmo**: Define formalmente as etapas do ciclo de criptografia (SubBytes(), ShiftRows(), MixColumns(), AddRoundKey()) e suas inversas para descriptografia (InvSubBytes(), InvShiftRows(), InvMixColumns()).
- **Funções Auxiliares de Chave**: Define SubWord() (aplicação da S-box a uma palavra de 4 bytes) e RotWord() (permutação cíclica dos bytes em uma palavra).
- **Operadores**: Mapeia a operação XOR ($\oplus$), a multiplicação polinomial módulo $x^4 + 1$ ($\otimes$), a multiplicação no corpo finito $GF(2^8)$ ($\bullet$) e o vetor de constantes de rodada Rcon[].

## Capítulo 3: Notação e Convenções (Notation and Conventions)

O Capítulo 3 estabelece as convenções de ordenação, representação de dados (bits, bytes e palavras) e a estrutura matricial interna sobre a qual o algoritmo AES opera.

### 3.1 Entradas e Saídas (Inputs and Outputs)

- **Tamanho dos Blocos**: Os dados de entrada e saída do algoritmo consistem estritamente em sequências de 128 bits (referidas como blocos).
- **Tamanho da Chave**: A chave de cifra (Cipher Key) consiste em uma sequência de 128, 192 ou 256 bits.
- **Indexação de Bits**: Os bits dentro de uma sequência são indexados de $0$ até $\text{comprimento} - 1$ (ou seja, de $0$ a $127$, $0$ a $191$ ou $0$ a $255$, dependendo do tamanho da chave/bloco).

### 3.2 Bytes (Bytes)

- **Unidade Fundamental**: A unidade básica de processamento no AES é o byte (grupo de 8 bits contíguos).
- **Representação Polinomial**: Cada byte $\{b_7, b_6, \dots, b_0\}$ é interpretado como um elemento de corpo finito por meio de representação polinomial. Por exemplo, o byte `{01100011}` representa o polinômio $x^6 + x^5 + x + 1$.
- **Notação Hexadecimal**: Os bytes são expressos em hexadecimal entre chaves (ex.: `{63}` representa o byte `{01100011}`).
- **Bit Extra de Transbordo**: Quando uma operação envolve um noveno bit (bit $b_8$), este aparece como `{01}` antes do byte (ex.: `{01}{1b}`).

### 3.3 Arranjos de Bytes (Arrays of Bytes)

- **Mapeamento da Sequência de Bits**: O bloco de entrada de 128 bits é dividido em um arranjo de 16 bytes $a_0, a_1, \dots, a_{15}$.
- **Ordem dos Bits no Byte**: O bit de menor índice na sequência de entrada corresponde ao bit mais significativo (bit 7) do byte.

### 3.4 O Estado (The State)

- **Estrutura Bidimensional**: As operações do AES ocorrem dentro de uma matriz bidimensional de bytes com 4 linhas e $N_b$ colunas, denominada State. Como $N_b = 4$ para o AES, o State é uma matriz $4 \times 4$ contendo 16 bytes.
- **Mapeamento de Entrada**: O vetor de entrada é copiado para o State preenchendo coluna por coluna, conforme a regra $s[r, c] = \text{in}[r + 4c]$.
- **Mapeamento de Saída**: Ao término, o State é copiado de volta para o vetor de saída: $\text{out}[r + 4c] = s[r, c]$.

### 3.5 O Estado como um Arranjo de Colunas (The State as an Array of Columns)

- **Agrupamento em Palavras (Words)**: Os 4 bytes de cada coluna do State formam palavras de 32 bits.
- **Vetor de Palavras**: O State também pode ser visualizado como um vetor unidimensional de 4 palavras $w_0, w_1, w_2, w_3$. Isso facilita a execução de operações orientadas a colunas, como MixColumns().

## Capítulo 4: Preliminares Matemáticas (Mathematical Preliminaries)

Apresenta os fundamentos matemáticos necessários para compreender as transformações e operações do algoritmo AES. Todos os bytes no AES são interpretados como elementos do corpo finito $GF(2^8)$.

### 4.1 Adição (Addition)

- **Operação em $GF(2^8)$**: A adição equivale à operação XOR (representada por $\oplus$).
- **Propriedades**: A subtracão de polinômios é idêntica à adição.
- **Nível de Byte**: A adição corresponde diretamente ao XOR bit a bit entre dois bytes. Exemplo: `{57} \oplus {83} = {d4}`.

### 4.2 Multiplicação (Multiplication)

- **Operação Polinomial**: A multiplicação em $GF(2^8)$ (denotada por $\bullet$) corresponde à multiplicação polinomial reduzida módulo um polinômio irredutível de grau 8.
- **Polinômio Irredutível do AES**: $m(x) = x^8 + x^4 + x^3 + x + 1$, representado em hexadecimal como `{01}{1b}`.
- **Inverso Multiplicativo**: Calculado utilizando o Algoritmo de Euclides Estendido.

#### 4.2.1 Multiplicação por $x$ e a Função xtime()

- **Conceito**: Multiplicação por $x$ (byte `{02}`) resulta no deslocamento dos coeficientes para a potência superior.
- **A Operação xtime()**: Consiste em um deslocamento de 1 bit à esquerda (left shift), seguido por um XOR bit a bit com `{1b}` caso o bit 7 original fosse 1.

### 4.3 Polinômios com Coeficientes em $GF(2^8)$

- **Estrutura de Palavras de 4 Bytes**: O AES também define polinômios de quatro termos da forma $a(x)$, representando uma palavra de 32 bits.
- **Adição**: XOR bit a bit entre as palavras de 32 bits completas.
- **Multiplicação Modular**: Multiplica-se algebraicamente dois polinômios de quatro termos, e reduz-se o produto módulo o polinômio $x^4 + 1$.

## Capítulo 5: Especificação do Algoritmo (Algorithm Specification)

Define formalmente o algoritmo AES em detalhes.

### 5.1 O Algoritmo de Criptografia (Cipher)

A criptografia opera em blocos de 128 bits, utilizando chaves de 128, 192 ou 256 bits ao longo de 10, 12 ou 14 rodadas.

- **SubBytes()**: Substituição não linear individual de cada byte do State por meio de uma tabela S-box invertível.
- **ShiftRows()**: Deslocamento cíclico dos bytes das três últimas linhas do State por diferentes offsets.
- **MixColumns()**: Processa o State coluna por coluna, multiplicando-a módulo $x^4 + 1$ por um polinômio fixo.
- **AddRoundKey()**: Adição bit a bit via operação XOR de cada coluna do State com uma palavra correspondente da agenda de chaves.
- **Rodada final**: Difere das demais por omitir a transformação MixColumns().

### 5.2 Expansão de Chave (Key Expansion)

A rotina de expansão transforma a chave secreta original em uma agenda de chaves composta por um vetor linear de palavras de 32 bits.
- Combina XOR da palavra anterior com a palavra situada $N_k$ posições antes.
- Aplica transformações `RotWord()`, `SubWord()` e `Rcon[]` (XOR com constante de rodada).

### 5.3 Cifra Inversa e Descriptografia (Inverse Cipher)

A descriptografia obtém o texto claro aplicando as transformações inversas na ordem oposta.

- **InvShiftRows()**: Inverte os deslocamentos cíclicos das linhas.
- **InvSubBytes()**: Aplica a S-box inversa.
- **InvMixColumns()**: Multiplica as colunas pelo polinômio inverso.
- **AddRoundKey()**: É idêntico à criptografia, pois o XOR é sua própria inversa.

## Capítulo 6: Questões de Implementação (Implementation Issues)

Aborda requisitos operacionais e critérios de conformidade.

### 6.1 Requisitos de Comprimento de Chave

- **Suporte Mínimo**: Deve suportar pelo menos um dos comprimentos (128, 192, 256 bits).
- **Interoperabilidade**: Pode opcionalmente oferecer suporte a mais tamanhos.

### 6.2 Restrições de Chaveamento

- **Ausência de Chaves Fracas**: Não foram identificadas chaves fracas para o AES.
- **Seleção Livre**: Qualquer combinação binária correta é segura.

### 6.3 Parametrização e Sugestões

- **Parâmetros Fixados**: Bloco de 128 bits e variações definidas de chave/rodadas.
- **Critério de Validade**: Qualquer implementação que produza a saída exata especificada no padrão é válida, independentemente da plataforma.
- **Otimizações**: A norma incentiva técnicas (tabelas de busca, rearranjos de memória) para obter eficiência.

*(Fim do resumo baseado na especificação FIPS 197).*
