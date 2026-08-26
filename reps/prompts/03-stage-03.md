# Prompt – Stage 3 (Inteligência)

Você está trabalhando no projeto **reps** em `c:\Users\Josias\Documents\reps`. Leia primeiro:
- `CLAUDE.md`
- `docs/04-features-spec.md` (F3.3, F4.2, F5.2, F6, F8)
- `docs/stages/stage-03-intelligence.md`
- `scripts/.stage-02-summary.md`

**Pré-requisito:** Stage 2 com sync local-first funcionando e modo execução básico.

Sua tarefa é entregar **todos** os itens E3.1 a E3.9 do `docs/stages/stage-03-intelligence.md`.

## Regras

1. Siga `prompts/00-prompt-protocol.md`.
2. Esta é a fase em que **os diferenciais aparecem**. Investir em qualidade > velocidade.
3. Commit por entregável com `feat(stage-3): E3.X – <descrição>`.

## Ordem sugerida de execução

1. **E3.1 – Timer de descanso fullscreen** ⭐
   - `lib/features/workout/presentation/rest_timer_overlay.dart`
   - Rota fullscreen com `fullscreenDialog: true` ou route_builder customizado
   - Barra circular grande (`CustomPainter` ou `flutter_animate`)
   - Botões +15s / −15s / pular / pausar
   - `vibration` + `audioplayers` para alerta
   - `wakelock_plus` mantém tela acesa
   - Configurações em Settings: vibração on/off, som (lista pré-carregada em `assets/sounds/`)
   - Dispara automaticamente após `WorkoutController.confirmSet()`

2. **E3.2 – Substituição inteligente** ⭐
   - `lib/domain/usecases/substitute_exercise.dart`
   - Query: `padrao_movimento == X AND grupo_muscular_primario == Y`
   - Ordenação:
     - Score 1: tem `set_logs` deste exercício para o user
     - Score 2: mesmo equipamento
     - Score 3: tudo o mais
   - `SubstituteSheet` mostra cards com nome, GIF preview, última carga
   - Ao escolher: a partir desta série, `set_logs.exercise_id = novo`, `substituido_de_exercise_id = original`
   - Herda nº séries + reps; carga = última do substituto OU vazio
   - Evento PostHog `exercise_substituted`

3. **E3.3 – Motor de progressão** ⭐
   - `lib/domain/usecases/progression_engine.dart`
   - Função `Carga sugerirCarga(Exercise ex, List<SetLog> ultimaSessao, FaixaReps faixa)`
   - Tabela de regras no doc; testes unitários para cada cenário
   - Considerar `padrao_movimento` para distinguir composto vs. isolador
   - Quando ≥ 3 sobrescritas seguidas do usuário, salvar `incremento_kg` customizado por exercício (nova tabela `user_exercise_settings` local + Postgres)

4. **E3.4 – Detecção de PR**
   - Após cada `set_logged`, queries:
     - `MAX(carga_kg)` para o exercise_id, comparar com nova
     - `MAX(carga_kg * reps_realizadas)` (volume) idem
     - `MAX(reps_realizadas) WHERE carga_kg = nova carga`
   - Se PR → push de notificação no toast persistente (`SnackBar` com action "ver recordes")
   - `RecordsScreen` em `lib/features/records/`

5. **E3.5 – Módulo cardio**
   - `lib/features/cardio/`
   - `CardioListScreen` + `CardioFormSheet`
   - Persistência via Drift + sync via mesma engine
   - Integrar no `HistoryScreen` (linha do tempo)

6. **E3.6 – Exportação CSV/JSON**
   - `lib/features/settings/data/export_service.dart`
   - CSV: cabeçalho + uma linha por `set_log`
   - JSON: estrutura aninhada `{sessions: [{...., set_logs: [...]}, cardio_sessions: [...]}`
   - `share_plus` para distribuir
   - Disponível em modo convidado também
   - Evento PostHog `data_exported`

7. **E3.7 – Templates**
   - `assets/templates/templates.json` com 3 templates (PPL, U/L, FB)
   - Cada template referencia exercícios por slug (campo extra na biblioteca, derivado do nome)
   - UI no onboarding e em `+ Nova rotina`: "Usar template"

8. **E3.8 – Resumo semanal**
   - `lib/features/insights/weekly_volume_screen.dart`
   - Query: somar `reps_realizadas * carga_kg` agrupado por `grupo_muscular_primario` para a semana ISO atual e a anterior
   - Gráfico de barras horizontais com diff em %
   - Highlight para grupos com 0 séries

9. **E3.9 – Polimento e beta**
   - Tema escuro padrão, claro como opção (segue sistema)
   - Logo "reps" + splash
   - Ícone do app (gerar em `assets/icon/`)
   - Política de privacidade em `assets/legal/privacidade.md` + tela embedded
   - 🛑 HUMAN STEP: gerar `.aab` e `.ipa` de release, subir TestFlight e Play Internal

## Definição de pronto

- Todos os critérios de aceite de `stage-03-intelligence.md` ✅
- `flutter analyze` limpo, `flutter test` passa
- Smoke test manual com cenários do doc (timer com tela bloqueada, substituição, PR detection, exportação)
- README raiz: "Status: MVP completo – pronto para beta"
- `scripts/.stage-03-summary.md` com 5 linhas de fechamento + próximos passos
