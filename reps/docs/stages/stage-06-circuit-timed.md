# Stage 6 – Treinos de circuito/bi-set + exercícios por tempo (pós-MVP / V1.x)

> **Status:** plano de trabalho. Não faz parte do MVP (Fases 1–3).
> **Progresso:** ✅ **Feature B (exercício por tempo)** — migração Drift v6 +
> Supabase 0006, `PlannedSet.duracaoAlvoSegundos`, `Exercise.medidaPorTempo`,
> `TimedExerciseOverlay`, timer no `workout_screen` e campo "Duração (s)" no
> editor. ✅ **Feature A (circuito/bi-set)** — migração Drift v7 + Supabase 0007
> (`grupo_id`/`grupo_tipo`/`rounds`), `GrupoTipo`, `buildActiveSlots`
> (intercalamento testado), rest gating por rodada, badge de grupo na execução e
> UI de agrupar no `routine_builder_screen`. ✅ **E6 (PR/progressão por tempo)**
> — PR de maior duração (`PrTipo.duracaoMax`) + `suggestTimed`, wiring no
> `confirmSet`, card de progressão por tempo na execução e `duracao_segundos`
> no export CSV/JSON.
> **Pré-requisito:** Fases 1–3 com critérios de aceite ✅.
> **Decisões de escopo já tomadas (não reabrir sem pedido):**
> - Exercício por tempo = **flag no `Exercise` + override por série** (`PlannedSet.duracaoAlvoSegundos`).
> - Timer do exercício por tempo = **regressivo** (conta do alvo → 0, igual ao descanso).
> - Uma única migração Drift (**v5 → v6**) e uma migração Supabase (**0006**) cobrem as duas features.

## Objetivo de saída

Duas features que cruzam as mesmas camadas (dados → domínio → execução → UI):

1. **Circuito e bi-set.** O usuário agrupa 2+ exercícios num bloco executado de
   forma intercalada (A·s1 → B·s1 → descanso → A·s2 → B·s2 → …), sem descanso
   dentro de uma rodada e com descanso só ao fechar a rodada.
2. **Exercício por tempo.** Exercícios isométricos/de tempo (prancha, etc.)
   exibem um **timer regressivo** no lugar do input de REPS, registrando a
   duração executada em vez de repetições.

---

## 1. Diagnóstico do código atual

Levantamento que fundamenta o plano (arquivos reais):

- **Modelo de rotina:** `routine_exercises` é uma lista plana; cada linha tem
  `ordem` + `series_planejadas` (JSON `PlannedSet[]`). **Não existe conceito de
  agrupamento.** ([routines_table.dart](../../lib/data/local/tables/routines_table.dart))
- **`PlannedSet`** ([planned_set.dart](../../lib/domain/entities/planned_set.dart)):
  `repsAlvoMin/Max`, `cargaAlvo`, `descansoSegundos`, `tipoSerie`. O enum
  `TipoSerie` já tem o valor `superset`, mas hoje é só uma *tag por série* — não
  agrupa nem altera a execução.
- **Execução** ([workout_controller.dart](../../lib/features/workout/data/workout_controller.dart#L115)):
  `startFromRoutine` monta `slots` de forma **linear** — todas as séries do
  exercício A, depois todas do B. `ordemNoTreino` = índice do exercício e é usado
  em todo lugar (insights, PR, agrupamento de UI, `jumpToNextExercise`).
- **Descanso:** disparado em [workout_screen.dart:168](../../lib/features/workout/presentation/workout_screen.dart#L168)
  após **todo** `confirmSet`, com `planned.descansoSegundos`. `RestTimerOverlay`
  já faz countdown + vibração/beep/wakelock/notificação.
- **`Exercise`/`SeedRow`** ([exercise.dart](../../lib/features/library/domain/exercise.dart), [exercises_seed.dart](../../lib/features/library/data/exercises_seed.dart)):
  **sem campo de tipo de medida.** Tudo assume reps.
- **`set_logs`** ([sessions_table.dart](../../lib/data/local/tables/sessions_table.dart#L26)):
  grava `reps_realizadas` + `carga_kg`. **Sem coluna de duração.**
  Drift `schemaVersion = 5` ([database.dart:44](../../lib/data/local/database.dart#L44)).

**Reuso obrigatório (não reimplementar):**
- `RestTimerOverlay` — extrair um núcleo compartilhado de timer (countdown +
  vibe/beep/wakelock) e reaproveitar no timer de exercício por tempo.
- `RoutineService.updateExerciseSeries` — caminho de persistência do editor.
- Padrão de migração Drift (`addColumn`) já presente em [database.dart](../../lib/data/local/database.dart#L47).

---

## E1 — Migração de dados (fundação; bloqueia tudo)

Uma migração Drift cobre as duas features. **Não** reaproveitar `reps_realizadas`
para guardar segundos (poluiria PR/progressão/insights, que tratam reps como reps).

### Drift (schemaVersion 5 → 6)

`RoutineExercises` (Feature A — agrupamento):
- `grupoId` `text().nullable()` — exercícios com mesmo `grupoId` = um bloco.
- `grupoTipo` `text()` default `'normal'` — `normal` | `bi_set` | `circuito`.
- `rounds` `integer().nullable()` — nº de rodadas do circuito (bi-set deriva do nº de séries).

`SetLogs` (Feature B — tempo):
- `duracaoSegundos` `integer().nullable()` — duração executada da série.

Bump `schemaVersion → 6` e estender `onUpgrade` com `addColumn` para as 4 colunas
(`from < 6`). Rodar `build_runner` antes de `analyze` (ver memória do toolchain).

### Supabase (`0006_circuito_tempo.sql`)

Espelhar as colunas: `routine_exercises` (`grupo_id uuid null`, `grupo_tipo text`,
`rounds int null`) e `set_logs` (`duracao_segundos int null`). Atualizar
[docs/03-data-model.md](../03-data-model.md) (tabelas `routine_exercises`,
`set_logs`) e o `tipo_serie`/jsonb de `series_planejadas`.

### Critério de aceite
- [ ] App migra de v5 → v6 sem perder dados; `build_runner` regenera `database.g.dart`.
- [ ] Migration Supabase aplica e RLS inalterada.

---

## E2 — Domínio (`PlannedSet` + `Exercise`)

### Feature B — medida por tempo
- `Exercise`/`SeedRow`: novo campo `medidaPorTempo` (bool, default `false`).
  Marcar exercícios isométricos no `exercisesSeed` (prancha e afins). Hoje o seed
  **não tem** nenhum exercício de tempo → incluir os candidatos junto.
- `PlannedSet`: novo campo `duracaoAlvoSegundos` (int?, default `null`).
  Override por série: série timed quando o exercício é `medidaPorTempo` **ou** a
  série tem `duracaoAlvoSegundos != null`. Atualizar `toJson`/`fromJson`/`copyWith`/`encode`.

### Feature A — agrupamento
- O agrupamento vive em `routine_exercises` (E1), não em `PlannedSet`. No domínio
  de execução, `ActiveSetSlot` ganha `grupoId`, `grupoTipo`, `round` (controle de
  fluxo) — **separado** de `ordemNoTreino`, que continua identificando o exercício
  (para insights/PR não quebrarem).

### Critério de aceite
- [ ] `PlannedSet` serializa/desserializa `duracaoAlvoSegundos` com retrocompat (campo ausente → null).
- [ ] Testes de `PlannedSet.encode/decode` cobrindo o novo campo.

---

## E3 — Execução (`WorkoutController`) ⚠️ ponto de maior risco

### A — intercalar slots
Reescrever o builder de `slots` em [workout_controller.dart:115-132](../../lib/features/workout/data/workout_controller.dart#L115):
- Bloco `normal`: comportamento atual (todas as séries do exercício em sequência).
- Bloco `bi_set`/`circuito`: laço externo por **rodada**, laço interno pelos
  exercícios do grupo. `ordemNoTreino` permanece = identidade do exercício;
  `round` + `grupoId` controlam a ordem de visita.
- **Auditar** `jumpToNextExercise` ([:281](../../lib/features/workout/data/workout_controller.dart#L281)) e
  `substituteCurrent` ([:242](../../lib/features/workout/data/workout_controller.dart#L242)): ambos
  varrem por `ordemNoTreino` contíguo — premissa quebrada pelo intercalamento.

### A — gating do descanso
Em [workout_screen.dart `_confirm`](../../lib/features/workout/presentation/workout_screen.dart#L150):
não abrir `RestTimerOverlay` quando o próximo slot é do mesmo `grupoId` **e** mesma
`round`. Descanso só ao fechar a rodada (usa `descansoSegundos` do último exercício do grupo).

### B — registrar duração
`confirmSet` aceita `duracaoSegundos` (int?) e grava em `set_logs.duracao_segundos`.
Para série timed, `reps_realizadas` fica `null`.

### Critério de aceite
- [ ] Bi-set de 2 exercícios × 3 séries executa A·s1→B·s1→descanso→A·s2→… (teste de unidade do builder).
- [ ] Circuito de 3 exercícios × N rodadas idem.
- [ ] Sem descanso entre exercícios da mesma rodada; com descanso ao fechar.
- [ ] `jumpToNextExercise`/`substituteCurrent` corretos dentro de um grupo.

---

## E4 — UI de execução (`workout_screen`)

### B — timer no lugar de REPS
- Extrair de `RestTimerOverlay` um núcleo `_TimerCore` (countdown, vibe/beep,
  wakelock, notificação) e reusar.
- Exercício timed: trocar o `_NumberInput` de REPS por um **timer regressivo**
  (conta de `duracaoAlvoSegundos` → 0). Ao concluir/parar, registra o tempo
  decorrido como `duracaoSegundos`. **Carga continua** (prancha com peso, farmer carry).
- Ajustar `_hydrateFromCurrent`, `_SeriesOverview` (mostrar `mm:ss` em vez de
  `carga×reps`), `_LastTimeRow` e o card de ALVO (alvo em segundos).

### A — sinalização do bloco
- Header/badge indicando "BI-SET" / "CIRCUITO — rodada 2/4" para o usuário
  entender o intercalamento.

### Critério de aceite
- [ ] Exercício por tempo mostra timer regressivo; reps somem; carga permanece.
- [ ] `RestTimerOverlay` continua funcionando (núcleo compartilhado sem regressão).
- [ ] Bloco de circuito/bi-set visualmente identificável durante a execução.

---

## E5 — UI de montagem (editor / routine builder)

### B — editor
[routine_exercise_editor_sheet.dart](../../lib/features/routines/presentation/routine_exercise_editor_sheet.dart):
exercício `medidaPorTempo` → campo **"Duração (s)"** no lugar de "Reps min/max".

### A — agrupar exercícios
O editor atual edita **um** exercício. Bi-set/circuito precisam de fluxo novo no
**routine builder** ([routine_builder_screen.dart](../../lib/features/routines/presentation/routine_builder_screen.dart)):
ação "agrupar" que atribui `grupoId`/`grupoTipo`/`rounds` a 2+ exercícios
adjacentes; visual de bloco; desagrupar.

### Critério de aceite
- [ ] Criar bi-set e circuito pela UI; persistir; reabrir mantém o grupo.
- [ ] Editor mostra duração para exercício por tempo.

---

## E6 — Downstream ✅

`PrDetector` e `ProgressionEngine` assumiam reps+carga. Implementado para
exercício por tempo:
- **PR.** `PrTipo.duracaoMax` + [`PrDetector.detectTimed`](../../lib/domain/usecases/pr_detector.dart): PR de maior duração e, em holds com peso (prancha/farmer com carga), também `cargaMax`. Disparado no `confirmSet` quando a série é por tempo (`duracaoSegundos != null`).
- **Progressão.** [`ProgressionEngine.suggestTimed`](../../lib/domain/usecases/progression_engine.dart) → `TimedProgressionSuggestion` (decisão + alvo de duração + delta em s). Regra espelha a de carga: todas atingiram o alvo → +5s (+10s se RPE fácil; mantém se RPE no limite); maioria abaixo → recua para a maior duração alcançada. `exerciseInsightProvider` escolhe carga vs tempo por `medidaPorTempo`/`porTempo`; `_ProgressionCard` mostra o card de duração (mm:ss, informativo).
- **Export.** `duracao_segundos` adicionado ao CSV e ao JSON ([export_service.dart](../../lib/features/settings/data/export_service.dart)) — dado é dono (princípio 4).
- Testes: [timed_progression_test.dart](../../test/timed_progression_test.dart) (8 casos).

---

## Ordem de implementação sugerida

`E1 (migração) → E2 (domínio) → E3 (execução) → E4 (UI execução) → E5 (UI montagem)`.
E1–E4 da Feature B são independentes da Feature A e podem ir primeiro (entrega de
valor menor e menos arriscada). A Feature A concentra o risco em E3 (intercalamento
+ gating). E6 fica para depois.

## Riscos / pontos de atenção

- **`ordemNoTreino` é overloaded** (identidade do exercício *e* ordem de execução).
  O intercalamento exige separar os dois conceitos — origem provável de bugs.
- **Retrocompat de `series_planejadas`**: rotinas antigas sem `duracaoAlvoSegundos`/
  grupo devem desserializar para os defaults.
- **`RestTimerOverlay` compartilhado**: extrair núcleo sem regredir o descanso atual.
