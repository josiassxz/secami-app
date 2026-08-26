# Prompt – Stage 2 (O motor)

Você está trabalhando no projeto **reps** em `c:\Users\Josias\Documents\reps`. Leia primeiro:
- `CLAUDE.md`
- `docs/03-data-model.md`
- `docs/04-features-spec.md` (F2, F4, F5, F7)
- `docs/stages/stage-02-engine.md`
- `scripts/.stage-01-summary.md` (estado deixado pelo Stage 1)

**Pré-requisito:** Stage 1 com `flutter analyze` limpo e todos os entregáveis E1.1–E1.7 concluídos.

Sua tarefa é entregar **todos** os itens E2.1 a E2.8 do `docs/stages/stage-02-engine.md`.

## Regras

1. Siga `prompts/00-prompt-protocol.md`.
2. Não trocar stack. Não reabrir decisões.
3. **Local-first é inviolável.** Toda escrita acontece primeiro no Drift, sync depois.
4. **Modo execução é o coração do app.** Investir tempo extra em UX aqui.
5. Commit por entregável com `feat(stage-2): E2.X – <descrição>`.

## Ordem sugerida de execução

1. **E2.1 – Drift database**
   - `lib/data/local/database.dart` com as 7 tabelas
   - DAOs por feature
   - Build runner: `dart run build_runner build --delete-conflicting-outputs`
   - Testes unitários básicos por DAO

2. **E2.2 – Sync engine** ⭐ (entregável crítico)
   - `lib/core/sync/sync_engine.dart`
   - `push()`: para cada tabela, pegar registros com `updated_at > last_sync_push_at`, fazer upsert via Supabase
   - `pull()`: para cada tabela, `GET ?updated_at=gt.<ts>`, fazer upsert local
   - Last-write-wins por linha
   - Fila de retry exponencial (2s, 4s, 8s, 16s, 30s teto)
   - Triggers: `WidgetsBindingObserver` para foreground, callback pós-`workout_completed`, `Timer.periodic(5min)` quando em foreground
   - `lastSyncProvider` (Riverpod) para banner de status na app bar
   - Testes: cenário offline → online, cenário 2 devices editando

3. **E2.3 – Construtor de rotinas**
   - `lib/features/routines/`
   - `RoutinesScreen` com `TabBar` Semana / Avulsos
   - `RoutineBuilderScreen` com drag-to-reorder e modal de seletor de exercício

4. **E2.4 – Editor de séries**
   - `RoutineExerciseEditorSheet`
   - Stepper para nº séries
   - Por série: 2 inputs reps min/max, 1 input carga, 1 input descanso (selector com presets 30/60/90/120s)
   - Dropdown tipo_serie
   - "Aplicar a todas" copia primeira linha
   - Para superset, segundo seletor de exercício

5. **E2.5 – Modo execução básico**
   - `lib/features/workout/`
   - Rota `/workout/:sessionId` em modo imersivo
   - State: estado da sessão atual (exercício atual, série atual, conjunto de set_logs)
   - UI: cabeçalho grande + 2 inputs (reps, kg) + botão "concluir" + botão "pular"
   - Persistência: cada toque em "concluir" → escrever em `set_logs` (local Drift)
   - Botão "finalizar" → escrever `workout_sessions.finalizado_em`
   - **Sem timer fullscreen** (Stage 3)
   - **Sem detecção de PR** (Stage 3)
   - **Sem substituição** (Stage 3)

6. **E2.6 – Histórico**
   - `lib/features/history/`
   - `HistoryScreen` linha do tempo agrupada por dia
   - `SessionDetailScreen` com lista de exercícios e set_logs
   - `ExerciseHistoryScreen` com 2 gráficos `fl_chart` (carga máx + volume)
   - Tabela de últimas 10 sessões

7. **E2.7 – Onboarding**
   - Splash mostra 3 cards
   - Default = "Treinar sem cadastro"
   - Skip persistente em shared_preferences

8. **E2.8 – Telemetria**
   - Disparar eventos: `workout_started`, `set_logged`, `workout_completed`, `set_skipped`

## Definição de pronto

- Todos os critérios de aceite de `stage-02-engine.md` validados
- `flutter analyze` limpo
- `flutter test` passa
- Smoke test manual em emulador: criar rotina, iniciar treino offline, registrar 5 séries, finalizar, ligar wifi, ver sync funcionar
- Atualizar README raiz: "Status: Stage 2 completo"
- Escrever `scripts/.stage-02-summary.md` com 5 linhas
