# Referência Visual — App IPASGO Saúde (Mobile)

> Documento de referência de design baseado em capturas de tela do aplicativo IPASGO Saúde (v2.1.9, iOS).
> Uso: guia de estilo para replicar a linguagem visual em outros projetos (UI mobile, prompts de design, protótipos).

---

## 1. Identidade Geral

**Estilo:** Flat design amigável e institucional, com forte identidade monocromática verde, cantos muito arredondados (pill/rounded-2xl+), ilustrações flat coloridas e tipografia bold geométrica. Transmite acessibilidade, saúde e confiança sem parecer frio.

**Palavras-chave para prompts:**
`friendly flat design`, `green monochromatic health app`, `rounded pill shapes`, `bold geometric sans-serif`, `flat illustrations`, `high contrast yellow accents`, `card-based mobile UI`

---

## 2. Paleta de Cores

### Cores principais
| Papel | Cor aproximada | Hex estimado |
|---|---|---|
| Verde escuro (fundo hero/home) | Verde floresta profundo | `#0E5A34` / `#0B4F2E` |
| Verde médio (fundo geral home) | Verde institucional | `#1B7A47` / `#17753F` |
| Verde-lima (cards e botões) | Verde-limão vibrante | `#B5D334` / `#AFCF3C` |
| Amarelo destaque | Amarelo mostarda/dourado | `#F2C230` / `#EDBD2C` |
| Verde texto/ícone (telas claras) | Verde escuro de marca | `#0E6B3A` |

### Cores de apoio
| Papel | Cor | Hex estimado |
|---|---|---|
| Fundo claro (telas internas) | Branco / off-white | `#FFFFFF` / `#F7F5EF` |
| Bege/creme (menu lateral, accordions) | Creme suave | `#F2EFE6` / `#EDE8DC` |
| Cinza texto secundário | Cinza médio | `#8A8A8A` |
| Cinza fundo informativo | Cinza claro | `#E4E4E4` |
| Vermelho (ações destrutivas) | Vermelho vivo | `#E8483F` |
| Verde confirmação | Verde escuro | `#1B7A47` |
| Azul borda destaque (card ativo) | Azul royal | `#3B6FE0` |

### Regras de uso
- **Home:** fundo verde escuro sólido, cards verde-lima, acentos amarelos (nome do usuário, círculos de ícone).
- **Telas internas/formulários:** fundo branco, verde escuro apenas em labels, bordas e ícones.
- **Menu lateral:** painel creme sobreposto ao fundo verde escurecido (overlay).
- Vermelho reservado exclusivamente para excluir/cancelar; verde para confirmar.

---

## 3. Tipografia

- **Família:** sans-serif geométrica arredondada e encorpada (aparência de *Poppins*, *Baloo 2* ou *Nunito* em pesos altos).
- **Hierarquia:**
  - Saudação/nome do usuário: bold, caixa alta, cor amarela sobre verde escuro.
  - Títulos de seção ("Pessoais", "Contato", "Endereço"): bold, preto, ~22–24px.
  - Títulos de tela (header): semibold/bold, preto, ~18px, centralizado à esquerda com botão voltar.
  - Labels de campos: bold, verde escuro, tamanho pequeno (~13px), posicionadas **sobre a borda do input** (estilo "notched outline").
  - Conteúdo de campos: regular/medium, preto, caixa alta em dados cadastrais.
  - Textos informativos: regular, cinza escuro, ~13–14px.
- **Caixa alta** usada extensivamente em nomes, listas de opções e valores de campos — reforça o tom institucional.

---

## 4. Formas e Componentes

### Cards de ação (home)
- Fundo verde-lima, cantos bem arredondados (~24px).
- Ilustração flat no canto superior direito.
- Rótulo bold verde-escuro no rodapé do card, alinhado à esquerda.
- Círculo amarelo com seta diagonal (↗) no canto superior esquerdo indicando navegação.
- Grid de 2 colunas com espaçamento generoso (~16px).

### Botões
- **Primário:** formato pill (border-radius total), fundo verde-lima, texto verde-escuro bold, ícone à esquerda.
- **Desabilitado:** fundo cinza claro, texto cinza.
- **Ações inline (texto):** "Cancelar" em vermelho, "Confirmar" em verde, sem fundo.
- **CTA largo (padrão externo/Itaú-like):** botão retangular arredondado full-width fixado na base.

### Inputs / Formulários
- Estilo **outlined com label recortada na borda** (Material "notched outline"), borda fina verde escura, cantos arredondados (~20px, quase pill).
- Ícone de ação à direita dentro do campo (ex.: bloqueado/não-editável = ícone ⊘ cinza).
- Placeholder cinza claro.
- Dropdowns com chevron ▾ à direita.

### Listas de seleção
- Itens em cards brancos com borda cinza sutil, cantos arredondados, texto bold centralizado em caixa alta.
- Campo de busca no topo: pill outline com ícone de lupa.
- Label de contexto ("Selecione uma opção") em cinza pequeno acima da lista.

### Accordions (agendamentos)
- Cabeçalho em barra bege/creme arredondada, texto bold caixa alta, chevron à direita.
- Estado vazio: texto cinza centralizado ("Nenhum agendamento encontrado").
- Item ativo: card branco com **borda azul** e barra lateral azul à esquerda, marca d'água diagonal ("Agendado") em azul translúcido, dados em texto denso com ações Cancelar/Confirmar no rodapé.

### Menu lateral (drawer)
- Painel creme deslizando da direita, canto superior esquerdo arredondado grande.
- Itens: ícone outline verde + label verde bold.
- Separadores: linhas finas verde-lima.
- Toggles estilo iOS: trilha verde escura quando ativo, thumb branco.
- Versão do app centralizada em texto pequeno no rodapé.

### Elementos flutuantes
- FAB circular (telefone/contato) no canto inferior direito: círculo com borda verde-lima e ícone verde-lima sobre fundo escuro.

### Caixas informativas
- Bloco cinza claro full-width, cantos levemente arredondados, ícone ⓘ à esquerda, texto pequeno com termo inicial em bold ("Importante:").

---

## 5. Ilustrações e Iconografia

- **Ilustrações:** estilo flat vetorial com personagens sem rosto detalhado, paleta restrita (verdes, amarelo, branco, laranja pontual), formas orgânicas de fundo (blobs/flores estilizadas) atrás do elemento principal.
- Temas: profissionais de saúde, calendário, telemedicina, documentos financeiros, autorizações.
- **Ícones de interface:** outline simples, traço médio, verde escuro; ícones funcionais (sino, perfil, lupa, chevron, lixeira).
- Lixeira vermelha preenchida para ações de exclusão em listas.

---

## 6. Layout e Espaçamento

- Margens laterais consistentes (~20–24px).
- Espaçamento vertical generoso entre campos (~16–20px).
- Headers de tela minimalistas: chevron "<" de voltar + título, sem fundo colorido nas telas internas.
- Home com hierarquia clara: logo → saudação → card do plano → grid de serviços → FAB.
- Conteúdo denso organizado por seções com títulos bold grandes.

---

## 7. Tom e Sensação

- Acolhedor, acessível e otimista — evita a frieza típica de apps institucionais.
- Verde como cor de saúde/confiança; amarelo como energia e destaque humano (nome do usuário).
- Ilustrações reduzem a carga burocrática das funções (financeiro, autorizações).
- Formulários seguem padrão familiar (outlined), priorizando legibilidade.

---

## 8. Prompt-resumo (para IA de design)

> "Mobile health insurance app UI, flat design. Deep forest green background (#0E5A34) with lime green rounded cards (#B5D334) and mustard yellow accents (#F2C230). Bold geometric rounded sans-serif (Poppins-like), uppercase labels. Pill-shaped buttons, outlined input fields with notched labels in dark green on white screens. Flat vector illustrations of healthcare scenes with organic blob backgrounds. Cream (#F2EFE6) side drawer with green outline icons and iOS-style toggles. Generous spacing, 24px corner radius, friendly institutional tone."
