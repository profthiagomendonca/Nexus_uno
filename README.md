# Nexus Uno: Elementos Químicos em Jogo

### 🎮 Jogue Online agora: [nexus-uno.netlify.app](https://nexus-uno.netlify.app)

**Nexus Uno** é um jogo de cartas digital estratégico e educativo desenvolvido na engine **Godot 4**. Inspirado nas mecânicas clássicas de jogos de descarte (como o UNO), o projeto transforma o aprendizado da Tabela Periódica em uma experiência competitiva, dinâmica e imersiva com temática de ficção científica (Sci-Fi).

### 🎯 Objetivo Pedagógico
O jogo foi projetado para facilitar a memorização e a compreensão das propriedades dos elementos químicos. Ao invés de decorar tabelas estáticas, os alunos interagem diretamente com os elementos através da jogabilidade. O jogo associa:
*   **Cores às Famílias Químicas:** (ex: Vermelho para Metais Alcalinos, Azul para Halogênios).
*   **Números aos Períodos:** Permite aos jogadores entenderem a organização horizontal da tabela periódica.
*   **Curiosidades Práticas:** Cada carta de elemento possui uma informação sobre sua aplicação no mundo real (ex: Lítio em baterias, Flúor na prevenção de cáries), conectando a química abstrata ao cotidiano do aluno.

### ⚙️ Mecânicas Principais
*   **Dinâmica de Descarte:** Os jogadores devem combinar cartas na mesa pelo mesmo Período (número) ou mesma Família (cor).
*   **Duelo contra IA:** O jogo conta com robôs programados com lógica de tomada de decisão, proporcionando um ambiente de desafio para um jogador contra múltiplos oponentes virtuais.
*   **Cartas Especiais Temáticas:**
    *   **Inversão & Bloqueio:** Alteram o fluxo do jogo usando representações de gases nobres e conceitos de física/química.
    *   **Reação +2:** Força o oponente a comprar cartas, podendo ser acumulada em combos estratégicos independentemente da família química.
    *   **Ligação Covalente (Troca de Mão):** Uma mecânica avançada onde o jogador pode escolher um alvo específico na mesa para realizar a troca de suas cartas, simulando o compartilhamento de elétrons.
    *   **Catalisador (Coringa) & Cadeia +4:** Permite ao jogador alterar a família química ativa na mesa.
*   **A Regra "Nexus!":** Um sistema de penalidade rápida onde o jogador deve denunciar adversários que ficam com apenas uma carta na mão.

### 💻 Tecnologias Utilizadas
*   **Engine:** Godot Engine 4 (GDScript)
*   **UI/UX:** Sistema de interface responsiva e dinâmica construída com `Control Nodes`, `Tweens` para animações fluidas de cartas e tipografia Sci-Fi customizada (Orbitron).
*   **Arquitetura:** Orientação a objetos aplicada ao controle de turnos, baralho instanciado dinamicamente e banco de dados iterativo de elementos químicos.
