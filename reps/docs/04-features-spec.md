# 04 – Especificação de features

Cada feature lista: regra de negócio, comportamento de UI, dependências de dados e critérios de aceite.

## F1 – Conta e autenticação

**Regra:** cadastro é **opcional**. Primeira abertura cai direto em modo convidado, dados locais. Cadastro é oferecido quando: (a) usuário acumula 3+ treinos OU (b) tenta acessar em segundo dispositivo.

- **MVP: e-mail/senha apenas.** Login social (Google/Apple) adiado para V1.1 — elimina configuração de OAuth na Apple Developer e console Google.
- Recuperação de senha por e-mail (link Supabase)
- Exportação CSV/JSON disponível inclusive para convidados
- Exclusão de conta → remoção completa em até 30 dias (LGPD)

**Aceite:**
- [ ] Convidado consegue treinar e fechar app sem nunca ver tela de cadastro
- [ ] Mesclagem `convidado → conta` preserva 100% do histórico local

## F2 – Construtor de treinos

### F2.1 Rotinas fixas
Vinculadas a dias da semana. Mesma rotina pode estar em múltiplos dias. Mesmo dia pode ter múltiplas rotinas opcionais (usuário escolhe ao iniciar).

### F2.2 Treinos avulsos
Pasta separada. Compartilham biblioteca e histórico, mas não poluem a agenda.

### F2.3 Variáveis por exercício
Para cada exercício na rotina:
- Nº de séries planejadas (com aquecimento opcional marcado separadamente)
- Faixa de reps alvo (ex.: 8–12) ou modo "até a falha"
- Carga inicial em kg, podendo variar por série
- Tempo de descanso alvo em segundos, por série ou global do exercício
- Tipo: normal, drop set, superset (com outro exercício), rest-pause
- Notas livres

**Aceite:**
- [ ] Reordenar exercícios via drag funciona em < 60fps
- [ ] Drop set permite registrar múltiplos pesos na mesma "série"
- [ ] Superset agrupa dois exercícios em um único bloco no modo execução

## F3 – Biblioteca de exercícios e substituição

### F3.1 Biblioteca
~100 exercícios curados, com GIF curto, nome pt-BR, descrição de uma frase e tags.

**GIFs são assets locais** (`assets/exercises/<slug>.gif`), declarados no `pubspec.yaml`. O campo `gif_url` no banco guarda o slug (ex.: `supino_reto_barra`), e o app resolve via `AssetImage('assets/exercises/${slug}.gif')`. Sem CDN, sem rede, sem placeholder de loading. V1.1 pode migrar para Supabase Storage quando precisar atualizar biblioteca sem release.

### F3.2 Tags
Três tipos por exercício:
- **Grupo muscular primário** (ver enum em [03-data-model.md](03-data-model.md))
- **Padrão de movimento**
- **Equipamento**

### F3.3 Substituição inteligente
Ao tocar "substituir", sistema oferece 3–5 alternativas com **mesmo padrão de movimento + mesmo grupo primário**, ordenadas por:

1. Exercícios com histórico do usuário (carga conhecida) primeiro
2. Mesma família de equipamento
3. Alternativas mais distantes que preservam o estímulo

Substituição **herda** nº de séries e faixa de reps, **não herda** carga (sugere última carga do exercício substituto, ou campo vazio).

### F3.4 Exercícios customizados
Usuário cria com nome, tags e foto/GIF opcional. Fica restrito à conta dele.

**Aceite:**
- [ ] Tela de substituição abre em < 200ms
- [ ] Histórico do exercício substituto aparece pré-preenchido se existir

## F4 – Modo execução

UI otimizada para academia: dedos suados, pouca luz, em movimento.

- Botões mínimo 48pt
- Contraste alto (tema escuro padrão)
- Sem scroll para registrar série
- Telas a 1m de distância: legíveis

### F4.1 Fluxo de uma série
1. Tela mostra: exercício atual, série atual/total, reps alvo, carga sugerida
2. Usuário executa fisicamente
3. Toca "concluir" → registra reps + carga (pré-preenchidos)
4. Timer de descanso inicia automático em tela cheia, barra de progresso visível a distância
5. Ao zerar → vibração + bipe
6. Próxima série / exercício

### F4.2 Recursos auxiliares
- Campo opcional **RPE/RIR** (1–10, um toque)
- Pular série/exercício com motivo (equipamento ocupado, fadiga, lesão, dor)
- Reordenar na hora (drag)
- **Detecção de PR**: ao registrar, sistema verifica recorde de peso máximo, volume ou reps → destaque sutil

**Aceite:**
- [ ] Registrar uma série leva ≤ 2 toques quando aceita valores sugeridos
- [ ] Timer fullscreen aparece em < 100ms após "concluir"
- [ ] Vibração funciona com app em background ou tela bloqueada (best-effort)

## F5 – Histórico e progressão

### F5.1 Visualizações
- Linha do tempo de treinos executados
- Página por exercício: gráfico de carga máxima, volume total, estimativa de 1RM (Epley)
- Recordes pessoais por exercício, com data
- Resumo semanal de volume por grupo muscular

### F5.2 Motor de progressão
Ao iniciar treino, sugere cargas com base na sessão anterior:

| Performance anterior | Sugestão |
|---|---|
| Todas as séries no topo da faixa de reps | +2,5kg compostos / +1kg isoladores |
| Faixa atingida em ≥ 50% das séries | manter carga |
| Maioria abaixo da faixa mínima | −5% |

Sugestões são **só sugestões** — usuário sempre pode sobrescrever. Sobrescritas frequentes ajustam os incrementos padrão por exercício.

**Aceite:**
- [ ] Gráfico de evolução abre em < 300ms com 6 meses de histórico
- [ ] Sugestão de carga aparece como valor pré-preenchido editável no modo execução

## F6 – Cardio

Modelo separado da musculação, mas integrado ao histórico geral.

- Modalidade (esteira, bicicleta, escada, corrida ao ar livre, remo, elíptico, outros)
- Duração, distância (opcional), intensidade percebida, calorias estimadas
- FC média e máxima (manual no MVP)
- Campos `external_source`, `external_id`, `synced_at` reservados para V2

**Aceite:**
- [ ] Registrar sessão de cardio em ≤ 4 toques
- [ ] Histórico aparece junto com treinos de musculação na linha do tempo

## F7 – Onboarding

Valor imediato. Usuário deve conseguir iniciar primeiro treino em ≤ 60 segundos.

- Modo convidado direto
- Biblioteca pré-populada
- Templates prontos: PPL, Upper/Lower, Full Body
- Tutorial **opcional**, dispensável em qualquer momento

## F8 – Exportação de dados

- Formato CSV (uma linha por `set_log`) e JSON (estrutura aninhada por sessão)
- Disponível em qualquer momento
- Funciona inclusive para conta convidada
- Sem paywall, sem feature gate

## F9 – Telemetria

Eventos PostHog (lista mínima):

| Evento | Quando |
|---|---|
| `app_open` | Cada abertura |
| `workout_started` | Toca em "iniciar treino" |
| `workout_completed` | Finaliza sessão |
| `set_logged` | Cada série registrada |
| `exercise_substituted` | Usa substituição |
| `timer_used` | Timer ativado pelo menos 1× na sessão |
| `pr_detected` | Sistema detecta PR |
| `data_exported` | Usuário exporta CSV/JSON |
| `account_created` | Cadastro completado |
| `account_deleted` | Pedido de exclusão LGPD |
