# Stage 2 – O motor (semanas 5–9)

**Objetivo de saída:** o app **já é utilizável na academia**, mesmo sem os diferenciais competitivos. Sync local-first funcionando.

## Pré-requisitos

- [ ] Stage 1 com todos os critérios de aceite ✅

## Entregáveis

### E2.1 – Banco local com Drift
- Mapear todas as 7 tabelas como entidades Drift em `lib/data/local/database.dart`
- Mesmo schema do Postgres, exceto `user_id` opcional para modo convidado
- DAOs por feature: `RoutineDao`, `ExerciseDao`, `SessionDao`, `SetLogDao`, `CardioDao`
- Migrações Drift versionadas

### E2.2 – Motor de sincronização local-first
- `lib/core/sync/sync_engine.dart` com:
  - `push()` – envia para Supabase tudo que `updated_at > last_sync_at` local
  - `pull()` – baixa do Supabase tudo que `updated_at > last_sync_at` remoto
  - Resolução last-write-wins por linha
  - Fila com retry exponencial em caso de erro de rede
- Gatilhos: app foreground, pós-finalizar sessão, intervalo de 5min em background
- Indicador visual de sync na app bar (ícone + última sincronização)
- **Funciona 100% offline**: todas as features abaixo escrevem no Drift primeiro

### E2.3 – Construtor de rotinas
- `RoutinesScreen`: duas abas "Semana" (rotinas fixas) e "Avulsos"
- `RoutineBuilderScreen`:
  - Nome, dias da semana (chips multi-select), tipo (fixo/avulso)
  - Lista de exercícios com drag-to-reorder (`ReorderableListView`)
  - Botão "+" abre `LibraryPickerSheet` (reusa busca da biblioteca)
  - Cada exercício na rotina abre `RoutineExerciseEditorSheet` para configurar séries

### E2.4 – Editor de séries planejadas
- `RoutineExerciseEditorSheet`:
  - Nº de séries (stepper +/-)
  - Por série: reps_alvo_min, reps_alvo_max, carga_alvo, descanso_segundos
  - Botão "aplicar a todas" para preencher rapidamente
  - Checkbox "aquecimento" por série
  - Dropdown tipo_serie: normal, drop_set, superset, rest_pause
  - Campo notas
- Para superset, abre segundo seletor de exercício

### E2.5 – Modo execução (versão básica)
> **Versão básica** = funcional, sem timer fullscreen, sem detecção de PR, sem substituição. Esses entram na Stage 3.

- `WorkoutScreen` em rota separada com modo imersivo (sem nav bar)
- Cabeçalho: nome do exercício, série atual / total, faixa de reps alvo, carga sugerida (= carga_alvo da rotina)
- Campos editáveis: reps realizadas, carga em kg (pré-preenchidos)
- Botão "concluir série" (grande, ≥ 64pt, contrastante)
- Botão "pular" com menu de motivo (equipamento_ocupado, fadiga, lesao, dor, outro)
- Botão "próximo exercício"
- Botão "finalizar treino" → cria `workout_sessions` com `finalizado_em`
- Persiste `set_logs` a cada toque em "concluir"
- Modo retrato bloqueado (paisagem é distração)

### E2.6 – Histórico
- `HistoryScreen`: linha do tempo agrupada por dia, mostra nome da rotina + duração + nº séries
- Tap em sessão → `SessionDetailScreen` com lista de exercícios e set_logs
- `ExerciseHistoryScreen` (a partir do detalhe da biblioteca ou de uma série):
  - Gráfico de carga máxima por sessão (`fl_chart` line chart)
  - Gráfico de volume total (carga × reps somados)
  - Estimativa de 1RM (Epley): `carga × (1 + reps/30)`
  - Tabela de últimas 10 sessões

### E2.7 – Onboarding mínimo
- Tela de boas-vindas com 3 cards: "Treinar sem cadastro", "Criar conta", "Importar de planilha (V2)"
- Default: "Treinar sem cadastro" → user_id local

### E2.8 – Telemetria de sessão
- Eventos PostHog: `workout_started`, `set_logged`, `workout_completed`, `set_skipped`

## Critérios de aceite (gate para Stage 3)

- [x] `flutter analyze` 0 issues e `flutter test` 12/12 OK
- [x] Drift roda em memória nos testes (validação do schema + DAOs)
- [ ] Criar rotina "Peito e Tríceps" com 5 exercícios, atribuir a segundas e quintas → aparece nos dois dias (testar com `flutter run`)
- [ ] Iniciar treino em modo avião, registrar 12 séries, finalizar, voltar online → 12 set_logs aparecem no Supabase em ≤ 30s
- [ ] Editar série no celular A, alterar mesma série no celular B com timestamp posterior → após sync, prevalece B
- [ ] Gráfico de evolução de "supino reto" mostra 6 pontos após 6 sessões com cargas diferentes
- [ ] Reabrir app interrompido durante treino reconstrói estado (V1.1 – atualmente perde o estado em memória, mas todas as séries já registradas estão salvas)
- [ ] Tela de execução legível a 1m de distância (validar fisicamente em academia)
