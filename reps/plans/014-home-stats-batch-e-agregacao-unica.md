# Plan 014: home_stats sem N+1, agregação de volume única no domain, autoDispose nos providers de agregação

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 7620a52..HEAD -- lib/features/routines/data/home_stats_provider.dart lib/features/insights/ lib/features/records/ lib/domain/`
> Se algum arquivo em escopo mudou desde o SHA, compare os excerpts com o
> código vivo antes de prosseguir; divergência = STOP.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED (autoDispose muda ciclo de vida de cache — ver Step 4)
- **Depends on**: none
- **Category**: perf + tech-debt
- **Planned at**: commit `7620a52`, 2026-07-16

## Why this matters

Três problemas no mesmo raio: (1) `homeStatsProvider` faz **1 query de
set_logs por sessão** dentro de um loop — a home paga 1+N queries a cada
abertura e N cresce para sempre; (2) é a **4ª cópia** da agregação "volume =
Σ carga×reps de logs executados por janela de tempo" (as outras:
weekly_volume, records, history) — a definição de volume pode divergir por
cópia; (3) `homeStatsProvider`, `recordsProvider` e `weeklyVolumeProvider`
não têm `.autoDispose`: o resultado fica cacheado após sair da tela e **não
recomputa quando o usuário termina um treino** — a home mostra stats velhos.

## Current state

- `lib/features/routines/data/home_stats_provider.dart` — o N+1 e a cópia da
  agregação (linhas 26–59):

  ```dart
  final homeStatsProvider = FutureProvider<HomeStats>((ref) async {
    final db = ref.watch(appDatabaseProvider);
    ...
    final sessions = await db.sessionDao.watchByUser(userId).first;
    ...
    for (final s in sessions) {
      ...
      final logs = await db.setLogDao.ofSession(s.id);   // <- N+1
      final vol = logs
          .where((l) => l.executada)
          .fold<double>(
            0, (acc, l) => acc + (l.cargaKg ?? 0) * (l.repsRealizadas ?? 0),
          );
      if (isThisWeek) volAtual += vol;
      if (isPrevWeek) volAnterior += vol;
    }
  ```

- `lib/features/insights/presentation/weekly_volume_screen.dart` — o padrão
  batch CORRETO já existe aqui (linhas 35–39) e a mesma fórmula de volume
  (linha 57):

  ```dart
  final sessions = await db.sessionDao.watchByUser(userId).first;
  final sessionById = {for (final s in sessions) s.id: s};
  final logs = await db.setLogDao.ofSessions(
    sessions.map((s) => s.id).toList(),
  );
  ...
  agg.volume += (l.cargaKg ?? 0) * (l.repsRealizadas ?? 0);
  ```

- `lib/features/records/presentation/records_screen.dart:25` —
  `recordsProvider` é `FutureProvider` sem autoDispose (mesmo batch
  `ofSessions` já usado).

- Providers de history JÁ usam `.autoDispose` (exemplar:
  `lib/features/history/data/history_providers.dart`). Convenção do repo
  para "modelo usado por 2+ features vai para `lib/domain/`" (CLAUDE.md,
  regra de domain).

- DAO batch existente: `db.setLogDao.ofSessions(List<String> ids)` (usado em
  weekly_volume e records; testado em `test/set_log_dao_batch_test.dart`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `C:/src/flutter/bin/dart format lib/ test/` | exit 0 |
| Analyze | `C:/src/flutter/bin/flutter.bat analyze` | 0 erros (1 info `anonKey` deprecado é pré-existente, ok) |
| Testes | `C:/src/flutter/bin/flutter.bat test` | all pass |

## Scope

**In scope**:
- `lib/domain/usecases/volume_aggregator.dart` (create)
- `test/volume_aggregator_test.dart` (create)
- `lib/features/routines/data/home_stats_provider.dart`
- `lib/features/insights/presentation/weekly_volume_screen.dart` (só a parte
  do provider/agregação — a UI não muda)
- `lib/features/records/presentation/records_screen.dart` (só `.autoDispose`)
- `plans/README.md` (status row)

**Out of scope**:
- `lib/features/history/**` — cópias de agregação de history são um deferido
  ANTIGO e mais entrelaçado com UI; não expandir o escopo.
- `lib/data/local/daos/set_log_dao.dart` — `ofSessions` já existe e serve.
- Qualquer mudança visual nas telas.

## Git workflow

- Branch: `advisor/014-home-stats-batch`
- Commits (um por passo lógico):
  `perf(home): elimina N+1 de set_logs no home_stats`,
  `refactor(domain): agregador de volume unico em usecases`,
  `fix(providers): autoDispose em homeStats/records/weeklyVolume`
- Não fazer push nem abrir PR sem instrução do operador.

## Steps

### Step 1: Criar o agregador no domain

`lib/domain/usecases/volume_aggregator.dart` — função pura (sem Riverpod, sem
DB), testável isolada:

```dart
/// Volume executado = Σ (carga_kg × reps) dos set_logs com executada=true,
/// filtrado por janela [from, to) sobre iniciado_em da sessão dona.
/// Definição única — home, insights e records devem usar ESTA função para
/// que "volume" signifique a mesma coisa em todo o app.
double volumeExecutado({
  required Iterable<SetLogRow> logs,
  required Map<String, WorkoutSessionRow> sessionById,
  required DateTime from,
  required DateTime to,
}) { ... }
```

Assine com os tipos Drift (`SetLogRow`, `WorkoutSessionRow` de
`lib/data/local/database.dart`) — exemplar de import: veja
`lib/domain/usecases/pr_detector.dart`.

**Verify**: `flutter analyze` → 0 erros.

### Step 2: Testes do agregador

`test/volume_aggregator_test.dart` (padrão: `test/one_rm_test.dart` — teste
puro, sem DB): logs executados dentro/fora da janela, `executada=false`
ignorado, carga/reps null tratados como 0, janela vazia = 0.

**Verify**: `flutter test test/volume_aggregator_test.dart` → all pass.

### Step 3: home_stats usa batch + agregador

Em `home_stats_provider.dart`: substituir o loop N+1 por:

```dart
  final sessions = await db.sessionDao.watchByUser(userId).first;
  final sessionById = {for (final s in sessions) s.id: s};
  final logs = await db.setLogDao.ofSessions(
    sessions.map((s) => s.id).toList(),
  );
  final volAtual = volumeExecutado(logs: logs, sessionById: sessionById,
      from: monday, to: today.add(const Duration(days: 1)));
  final volAnterior = volumeExecutado(... from: mondayPrev, to: monday);
```

CUIDADO com a semântica de janela: o código atual compara por DIA truncado
(`DateTime(y,m,d)`) com `!d.isBefore(monday) && !d.isAfter(today)` — a
janela nova deve produzir o MESMO resultado (semana atual = [monday,
amanhã)). Preserve também `treinsEstaSemana` e o streak (não mudam).

**Verify**: `flutter test` → all pass;
`grep -n "ofSession(s.id)" lib/features/routines/data/home_stats_provider.dart`
→ sem matches.

### Step 4: weekly_volume usa o agregador onde couber + autoDispose nos 3

- `weeklyVolumeProvider` agrega POR GRUPO muscular — a função do Step 1 soma
  total. Se generalizar exigir complicar a API, mantenha a agregação por
  grupo local e use o agregador só para a soma por janela SE encaixar
  limpo; senão deixe weekly_volume como está e registre no relatório
  ("agregador adotado em home_stats; weekly_volume deferido"). NÃO force.
- Adicione `.autoDispose` em: `homeStatsProvider`, `recordsProvider`,
  `weeklyVolumeProvider` (`FutureProvider.autoDispose<...>`).

Risco do autoDispose: recomputo a cada navegação. Com o N+1 eliminado
(Step 3) e batch nos outros dois, o recomputo é 2 queries — aceitável.

**Verify**: `flutter analyze` → 0 erros; `flutter test` → all pass; abrir
mentalmente o fluxo: home → treino → volta pra home = stats recomputados.

## Test plan

- `test/volume_aggregator_test.dart` (Step 2, ~5 casos).
- Suíte existente cobre home indireta e DAO batch
  (`test/set_log_dao_batch_test.dart`).
- Verificação final: `flutter test` all pass.

## Done criteria

- [ ] `grep -rn "ofSession(" lib/features/routines/` → nenhum uso singular em
      loop (só `ofSessions` batch)
- [ ] `lib/domain/usecases/volume_aggregator.dart` existe com teste próprio
- [ ] Os 3 providers usam `.autoDispose` (grep confirma)
- [ ] `flutter analyze` 0 erros; `flutter test` all pass
- [ ] Nenhum arquivo fora do escopo modificado (`git status`)
- [ ] `plans/README.md` status row atualizada

## STOP conditions

- Excerpts não batem com o código vivo (drift).
- O resultado de volume da home mudar com dados de teste idênticos (indica
  janela quebrada — não "ajuste o teste", investigue a semântica de datas).
- Generalizar o agregador para weekly_volume exigir mudar a API pública de
  mais de 1 arquivo fora do escopo.

## Maintenance notes

- Qualquer nova tela que mostre "volume" DEVE usar `volumeExecutado` — anote
  no code review de features futuras.
- As cópias de agregação em history (deferido antigo) são o próximo alvo
  natural — mesmo padrão deste plano.
- Se o recomputo por navegação pesar com bases grandes, a alternativa é
  `ref.keepAlive()` com invalidação explícita pós-`finish()` do treino — não
  implementar agora.
