# Stage 7 – Melhorias de arquitetura e confiabilidade do sync

> **Status:** plano de trabalho. Saído de auditoria de arquitetura (2026-06-12).
> **Progresso:** 🟢 Fases 1–5 **concluídas**. Mergeado na `main` local em
> 2026-06-12 (recomendador + stage-06 junto; revisão Ed. Física dispensada pelo
> dono). Trabalho final (4.1 mover exercise.dart, 4.3 god widgets, 5.3
> integration scaffold) na branch `refactor/stage-07-final`. Suite: 104 verdes.
> Pendente: push `main`→`origin`; integration test rodar em device; E6 (stage-06).
> **Pré-requisito:** commitar trabalho pendente do stage-06 (Fase 0).
> **Origem:** análise do código em `lib/` — 13 achados priorizados por
> gravidade. Fases 1–2 corrigem bugs latentes de dados; 3–5 são dívida
> estrutural que encarece os Stages 4 (coaching) e 5 (recomendador).

## Objetivo de saída

1. Nenhum cenário conhecido em que o usuário perde histórico (convidado→login,
   exercícios `extdb:`).
2. Sync confiável: batch, cursor sem clock skew, retry sem vazamento, falha
   isolada por linha.
3. `SyncEngine` extensível: adicionar tabela nova = registrar um
   `SyncableTable`, não editar 5 pontos do engine.
4. Convenções de organização documentadas (domain, singletons, tamanho de
   arquivo de tela).

---

## Fase 0 – Limpar a mesa (pré-requisito)

| # | Tarefa | Critério de aceite |
|---|--------|--------------------|
| 0.1 | Commitar trabalho pendente do stage-06 (circuit/timed: ~15 modificados + 7 novos) | `git status` limpo na branch `feat/recomendador-treinos` |
| 0.2 | Commitar `.claude/` (settings + 6 skills instaladas) | versionado |
| 0.3 | Decidir merge `feat/recomendador-treinos` → `main` (pendente revisão prof. Ed. Física). Fixes abaixo partem de `main` em branch própria | decisão registrada aqui |

## Fase 1 – Bugs latentes de dados (usuário perde histórico) ✅

Branch: `fix/sync-dados` (a partir de `feat/recomendador-treinos`).

| # | Tarefa | Detalhe | Teste |
|---|--------|---------|-------|
| 1.1 ✅ | Migração convidado→conta no login | [effectiveUserIdProvider](../../lib/features/auth/data/auth_providers.dart#L38) trocava o id no login e as linhas locais ficavam órfãs com uuid de convidado (somem da UI e nunca sobem no sync). Implementado [`AppDatabase.reassignGuestData`](../../lib/data/local/database.dart) (`UPDATE ... SET user_id` + `dirty` nas 3 tabelas com dono local: routines, workout_sessions, cardio_sessions; filhos seguem o pai e já ficam dirty), disparado no listener de signed-in em [sync_providers.dart](../../lib/core/sync/sync_providers.dart) antes do `runOnce` | ✅ [test/guest_migration_test.dart](../../test/guest_migration_test.dart) |
| 1.2 ✅ | Sync tolerar `extdb:` | [_exIdToDb](../../lib/core/sync/sync_engine.dart) retornava o slug `extdb:` verbatim → uuid inválido → exceção → sync inteiro em erro/retry. Agora retorna `null` para `extdb:` (fica local, mesmo tratamento de seed não-seedado) | ✅ [test/sync_extdb_test.dart](../../test/sync_extdb_test.dart) |

## Fase 2 – Confiabilidade do sync ✅

Branch: `fix/sync-confiabilidade` (a partir de `fix/sync-dados`).

| # | Tarefa | Detalhe |
|---|--------|---------|
| 2.1 ✅ | Push em batch | `_pushBatch`/`_pushJsons` em [sync_engine.dart](../../lib/core/sync/sync_engine.dart) fazem 1 `upsert` com lista + `markClean` em lote (`markRoutinesClean`/`markCleanAll` nos DAOs). Antes era N+1 (1 HTTP por linha dirty) |
| 2.2 ✅ | Cursor de pull sem clock skew | `_pullTable` grava cursor = `max(updated_at)` das linhas puxadas, não `DateTime.now()` do device. Sem linhas, não avança. Teste: [sync_cursor_test.dart](../../test/sync_cursor_test.dart) |
| 2.3 ✅ | Retry timer cancelável | `Timer? _retry` guardado em campo; `dispose()` cancela. Não dispara mais `runOnce` com DB fechado |
| 2.4 ✅ | Falha isolada por linha no push | `_pushJsons`: tenta batch; no erro, fallback por linha — linha quebrada fica dirty e re-tenta, não trava a fila. Recommender push idem (try/catch por linha) |

Testes Fase 2: [sync_cursor_test.dart](../../test/sync_cursor_test.dart),
[sync_batch_clean_test.dart](../../test/sync_batch_clean_test.dart).

## Fase 3 – Refactor estrutural (paga nos Stages 4/5) ✅

Guia: skill `flutter-apply-architecture-best-practices`.
Branch: `refactor/sync-estrutura` (a partir de `fix/sync-confiabilidade`).

| # | Tarefa | Detalhe |
|---|--------|---------|
| 3.1 ✅ | Extrair abstração `SyncableTable` | Mappers movidos para [sync_mappers.dart](../../lib/core/sync/sync_mappers.dart) (funções puras; tradução de exercise_id injetada por callback). [SyncableTable](../../lib/core/sync/syncable_table.dart) = name, ownerColumn, dirty, markClean, idOf, toJson(→null=fica local), applyPulled. `SyncEngine._syncables` registra as 5 tabelas; `_pushAll`/`_pullAll` viraram loop genérico (`_pushTable`/`_pullTable`). Adicionar tabela = registrar um descritor. Recomendador fica bespoke (push-only, scoped por uid). Teste roundtrip por mapper: [sync_mappers_roundtrip_test.dart](../../test/sync_mappers_roundtrip_test.dart) |
| 3.2 ✅ | Desacoplar sync dos services | `RoutineService`/`WorkoutController` não chamam mais `runOnce()` (removidos 12 + 4 pontos). `SyncEngine.startAutoSync` observa `AppDatabase.watchDirtyCount()` (5 tabelas) com debounce 3s; `RepsApp.build` mantém o engine vivo. Callers só escrevem (marcam dirty). Teste: [sync_batch_clean_test.dart](../../test/sync_batch_clean_test.dart) (watchDirtyCount) |

## Fase 4 – Organização de código ✅

Branches: `refactor/organizacao` (4.1 doc, 4.2, 4.4) + `refactor/stage-07-final`
(4.1 move, 4.3).

| # | Tarefa | Detalhe |
|---|--------|---------|
| 4.1 ✅ | Regra única de domain | Regra documentada no [CLAUDE.md](../../CLAUDE.md) (Estilo de código): usado por 2+ features → `lib/domain/`; senão fica na feature. `exercise.dart` **movido** para [lib/domain/entities/exercise.dart](../../lib/domain/entities/exercise.dart) (22 imports atualizados; `exercise_classifier` fica na library). |
| 4.2 ✅ | Eliminar singletons static | `LibraryRepository` e `HealthService` perderam o `static instance`/estado static: campos viram de instância, `libraryRepositoryProvider`/`healthServiceProvider` constroem uma instância por container (sem vazar entre testes). Warm-up do seed estendido relocado de `main()` para `_Bootstrap` (Consumer). Call sites de `HealthService.instance` migrados para `ref.read(healthServiceProvider)`. `updateCustom` segue como método de instância (não mais static — não vaza). |
| 4.3 ✅ | Quebrar god widgets | Widgets-folha privados extraídos para `presentation/widgets/*_widgets.dart` via `part`/`part of` (preserva privacidade e zero reescrita de call sites — só relocação): workout_screen 1212→634 linhas, routines_screen 614→112, library_screen 473→165. Comportamento idêntico (código byte-a-byte, validado por analyze + suite). Granularidade pode ser refinada (1 part por tela hoje). |
| 4.4 ✅ | `ActiveSetSlot` imutável | Campos de execução viram `final` + `copyWith`; `confirmSet`/`skipSet`/`substituteCurrent` trocam a referência do slot na lista. Suite workout verde. |

## Fase 5 – Menores + cobertura ✅

Branches: `refactor/organizacao` (5.1 tipo, 5.2) + `refactor/stage-07-final`
(5.3 integration scaffold).

| # | Tarefa |
|---|--------|
| 5.1 ✅ | Tipo central [ExerciseId](../../lib/domain/entities/exercise_id.dart) (`parse` → seed/extdb/custom/raw + `librarySlug`/`isCustom`). Os ~13 `startsWith('seed:')` espalhados (telas + sync_engine + coach_repository) passam a usá-lo. Teste: [exercise_id_test.dart](../../test/exercise_id_test.dart) |
| 5.2 ✅ | `_fold` (15 `replaceAll`) trocado por `removeDiacritics` do pacote `diacritic` em [library_repository.dart](../../lib/features/library/data/library_repository.dart) |
| 5.3 ✅ | Widget test do fluxo treino: [timed_exercise_overlay_test.dart](../../test/timed_exercise_overlay_test.dart) (render do alvo, contagem regressiva, +15s, pausa; plugins de plataforma mockados). Integration test (smoke do caminho feliz) scaffolded em [integration_test/app_test.dart](../../integration_test/app_test.dart) + driver [test_driver/integration_test.dart](../../test_driver/integration_test.dart) e dep `integration_test`. **Não roda no CI atual** (precisa device/emulador); compila limpo. TODO no arquivo: estender o fluxo quando os widgets ganharem `ValueKey`. |

---

## Ordem e dependências

```
Fase 0 → Fase 1 → Fase 2 → Fase 3 → Fase 4 → Fase 5
                  (2 e 3 podem inverter; 3.1 facilita 2.1)
```

- Fases 1–2: pequenas, alto valor, ~1 sessão cada.
- Fase 3: maior, mexe em código central — só com testes das Fases 1–2 verdes.
- Fases 4–5: incrementais, podem intercalar com features novas.
- Cada fase = branch própria + commits atômicos (`fix:` / `refactor:` / `test:`).
