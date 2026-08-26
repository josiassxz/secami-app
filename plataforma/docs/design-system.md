# Design System — Plataforma SECAMI

Fonte única de verdade para o redesenho visual do admin (React) e do app (Flutter).
Inspirado nas Apple HIG (clareza, deferência, profundidade; espaço generoso; tipografia
como hierarquia; movimento sutil e funcional) e no Material Design 3 (cor dinâmica,
elevação consistente, estados de interação bem definidos). A paleta em si (verde vivo +
lima + dourado) já foi definida a partir da `referencia visual/` do cliente — este
documento formaliza tudo em volta dela: tipografia, espaçamento, raio, sombra, estados
e movimento, pros dois codebases falarem a mesma língua visual.

**Não inventar valores fora daqui.** Se uma tela precisar de algo que não está listado
(uma cor nova, um espaçamento fora da escala), é sinal de que o problema é outro —
volte pra este doc antes de improvisar no CSS/Dart.

## 1. Princípios

1. **Hierarquia em 3 segundos.** Cada tela tem UM elemento dominante (título, número
   grande, ação primária). Tudo o mais é secundário visualmente — tamanho, peso e cor
   de texto comunicam importância antes do usuário ler uma palavra.
2. **Espaço é conteúdo.** Prefira respiro generoso a mais bordas/divisores. Se duas
   seções precisam de uma linha pra se separar, provavelmente falta espaço entre elas.
3. **Movimento é feedback, não decoração.** Toda transição existe pra confirmar uma
   ação ou orientar o olho (expandir, trocar de tela, carregar) — nunca só "pra ficar
   bonito". Durações curtas (ver §6), sem bounce/elastic.

## 2. Cor

Tokens já existem em `plataforma/admin/src/index.css` (`:root`/`.dark`) e
`reps/lib/core/theme/app_theme.dart` (`_lightScheme`/`_darkScheme`). Não duplicar
valores — referenciar os tokens (`var(--brand-primary)` / `scheme.primary`).

Resumo (ver os arquivos-fonte pro valor exato, incl. dark mode):

| Papel | Uso |
|---|---|
| `brand` (verde vivo) | Navegação ativa, seleção, ícones de destaque, foco |
| `lime` (verde-limão) | Fundo de botão primário e cards de acesso rápido — **nunca** texto/ícone sobre fundo claro |
| `gold` | Selos/badges circulares, acento secundário pontual |
| `info`/`success`/`warning`/`danger` | Só estado semântico (status, validação) — nunca decorativo |
| `surface`/`surface-alt` | Fundo de página e de card, nessa ordem de elevação |
| `content`/`content-soft`/`content-faint` | Texto primário/secundário/desabilitado |

### Camadas de estado (Material 3 "state layers")

Todo componente interativo aplica uma camada de opacidade sobre a própria cor de fundo
ao mudar de estado — não trocar de cor sólida, sobrepor opacidade:

| Estado | Opacidade sobre o fundo base |
|---|---|
| Hover | +8% (`hover:bg-black/[.08]` em fundo claro, ou `brightness`/`Color.alphaBlend` no Flutter) |
| Focus (teclado) | anel de 2px na cor `brand`, deslocado 2px do elemento (`focus-visible`) |
| Pressed/Active | +12%, mais leve `scale(.98)` (já usado nos botões do admin) |
| Disabled | conteúdo a 38% de opacidade, fundo a 12% — **nunca remover o elemento, só esmaecer** |

## 3. Tipografia

Admin usa Inter, app usa Poppins (decisão já tomada — Poppins é mais arredondada,
alinhada à referência visual mobile; Inter é mais neutra, melhor pra tabela densa).
Mesma escala nos dois, pra hierarquia consistente entre telas equivalentes:

| Papel | Tamanho | Peso | Admin (Tailwind) | App (Flutter) |
|---|---|---|---|---|
| Display | 34–56px | 700–800 | `text-4xl/5xl font-extrabold` | `displaySmall`–`displayLarge` |
| Headline | 22–28px | 700 | `text-2xl font-bold` | `headlineMedium`/`headlineLarge` |
| Title | 16–20px | 600 | `text-lg font-semibold` | `titleMedium`/`titleLarge` |
| Body | 14–16px | 400 | `text-sm`/`text-base` | `bodyMedium`/`bodyLarge` |
| Label/Caption | 11–13px | 600, tracking aberto | `text-xs font-semibold uppercase tracking-wide` | `labelSmall`–`labelLarge` |

Regra de hierarquia: cada tela tem no máximo **um** Display ou Headline por vez. Se
parecer que precisa de dois títulos do mesmo peso, um dos dois deveria ser Title.

## 4. Espaçamento

Grid de 4px (já é o padrão do Tailwind — não mudar). Usar só estes múltiplos:
`4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48 · 64`. No Flutter, formalizar como constantes
em `AppTheme` (`space4`..`space64`) em vez de números soltos em `EdgeInsets`.

Regras de aplicação:
- Padding interno de card/página: `16` (mobile) / `24` (admin desktop).
- Espaço entre seções de uma tela: `24`–`32`.
- Espaço entre itens de uma lista: `8`–`12`.
- Nunca menos que `4` entre dois elementos distintos (senão parecem um só).

## 5. Raio de borda

| Token | Valor | Uso |
|---|---|---|
| `sm` | 8px | Badges, chips pequenos |
| `md` | 12px | Cards, inputs, modais |
| `lg` | 20px | Cards de destaque (grid de acesso rápido) |
| `pill` | 999px | Botões primários, campo de busca, avatar |

## 6. Elevação e sombra

Sombra suave, nunca pesada (pedido explícito do cliente). Três níveis, mesma curva nos
dois codebases:

| Nível | Quando | CSS (admin) | Flutter |
|---|---|---|---|
| 0 — Flat | Fundo de página, divisores | sem sombra, só `border` 1px | `elevation: 0` + `BorderSide` |
| 1 — Resting | Card parado | `0 1px 2px rgba(0,0,0,.05), 0 4px 16px rgba(0,0,0,.04)` (já existe em `Card`) | `BoxShadow(blurRadius: 16, offset: Offset(0,4), color: shadow.withValues(alpha:.06))` |
| 2 — Raised | Card/botão em hover, popover, dropdown | `0 4px 12px rgba(0,0,0,.08), 0 2px 4px rgba(0,0,0,.06)` | mesmo shadow com blur maior (24) ao entrar em estado pressed/hover |
| 3 — Overlay | Modal, drawer, tooltip | `0 12px 32px rgba(0,0,0,.16)` | `Dialog` padrão do Material (já elevado) |

Nunca combinar nível 3 com fundo colorido saturado (lima/dourado) — só sobre `surface`.

## 7. Estados de interação (obrigatório em todo componente clicável)

Todo botão, input, card clicável, item de lista e ícone de ação precisa dos 4 estados
abaixo — sem exceção, isso é requisito, não opcional:

1. **Hover** (admin, mouse) — state layer §2 + sombra sobe um nível se for card/botão.
2. **Focus** (teclado, os dois) — anel visível 2px cor `brand`, nunca `outline: none`
   sem substituto. No Flutter, `FocusNode` + `focusColor`/`overlayColor` do M3.
3. **Active/Pressed** — state layer mais forte + `scale(.98)` (~120ms).
4. **Disabled** — opacidade 38–50%, `cursor: not-allowed` (admin), `onPressed: null`
   (Flutter, já desliga interação automaticamente) — nunca esconder o elemento.

Área de toque mínima: **44×44px** mesmo quando o elemento visual é menor (ex.: ícone
de 20px dentro de um `IconButton`/botão precisa de padding até fechar 44px).

## 8. Movimento

| Token | Duração | Curva | Uso |
|---|---|---|---|
| `fast` | 120ms | `ease-out` | hover, active, toggle |
| `base` | 200ms | `cubic-bezier(.2,0,0,1)` (M3 standard) | expandir/colapsar, troca de conteúdo |
| `slow` | 320ms | mesma curva | transição de tela/rota |

Sem "bounce", "elastic" ou overshoot — a referência é institucional, não lúdica.

## 9. Acessibilidade

- Contraste mínimo **AA** (4.5:1 texto normal, 3:1 texto grande/ícone) — todo par
  cor-de-fundo/cor-de-texto novo precisa ser conferido, não só "parece ok visualmente".
- Toda ação por clique tem equivalente por teclado (admin) e todo `Semantics`/label
  correto pro leitor de tela (app).
- Área de toque mínima 44×44px **no app** (superfície de toque, sempre). **No admin**
  (mouse-first, desktop), alvo mínimo de 32–36px é aceitável em ações densas de tabela
  — 44px em todo ícone de linha deixaria a grade de alunos/agenda com espaço
  desperdiçado; use 44px lá só em botões standalone fora de tabela (CTA de página,
  ações de formulário).

## 10. Responsividade

- **Admin = desktop-first.** Breakpoints Tailwind padrão (`sm`/`md`/`xl`). Tabelas
  colapsam pra cards empilhados abaixo de `md`; sidebar vira menu colapsável abaixo
  de `md` (hoje é sempre fixa — ver escopo do redesenho).
- **App = mobile-first**, single column, respeita safe-area (notch/home indicator).
  Sem breakpoint de tablet neste momento (fora de escopo).

## 11. Checklist por tela (usar em toda tela redesenhada)

- [ ] Um elemento dominante claro (hierarquia em 3s — §1)
- [ ] Espaçamento só na escala do §4, nada solto
- [ ] Todo componente interativo com os 4 estados do §7
- [ ] Contraste AA conferido em qualquer cor nova/reaproveitada de outro contexto
- [ ] Sombra no máximo nível 2 (nível 3 só em overlay) — §6
- [ ] Área de toque ≥44px em ícones/botões pequenos
- [ ] Sem cor saturada (lima/dourado) como fundo de texto longo — só selos/botões curtos
