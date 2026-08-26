# Plan 003: Eliminar N+1 de set_logs em Recordes e Volume Semanal

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md` — unless a reviewer
> dispatched you and told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 4796b7d..HEAD -- lib/data/local/daos/set_log_dao.dart lib/features/records/presentation/records_screen.dart lib/features/insights/presentation/weekly_volume_screen.dart`
> If any of these changed, compare the "Current state" excerpts against the live
> code before proceeding; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: 001 (so `flutter test` / analyze actually run; not a hard code
  dependency, but verify on a green baseline)
- **Category**: perf
- **Planned at**: commit `4796b7d`, 2026-06-20

## Why this matters

Two providers compute aggregates by looping over a user's workout sessions and
issuing **one Drift query per session** to fetch its set_logs. For a user with
50 sessions, the Recordes screen issues 50+ queries; the Volume Semanal screen
runs the same loop **twice** (current week + previous week), each re-fetching all
sessions and querying per session. This re-runs on every rebuild. A single
batched query (`WHERE session_id IN (...)`) collapses N queries into 1. The DAO
already uses this exact pattern for `markCleanAll` (batch update) — we mirror it
for reads.

## Current state

### File 1 — `lib/data/local/daos/set_log_dao.dart`

A drift `DatabaseAccessor`. It has `ofSession(String sessionId)` (single
session) and a batch *update* `markCleanAll(List<String> ids)`, but **no batch
read across sessions**. Relevant excerpts:

```dart
// lines 22–30
Future<List<SetLogRow>> ofSession(String sessionId) {
  return (select(setLogs)
        ..where((s) => s.sessionId.equals(sessionId) & s.deletedAt.isNull())
        ..orderBy([
          (s) => OrderingTerm(expression: s.ordemNoTreino),
          (s) => OrderingTerm(expression: s.numeroSerie),
        ]))
      .get();
}

// lines 79–84 — the batch pattern to mirror
Future<void> markCleanAll(List<String> ids) async {
  if (ids.isEmpty) return;
  await (update(setLogs)..where((s) => s.id.isIn(ids))).write(
    const SetLogsCompanion(dirty: Value(false)),
  );
}
```

`SetLogRow` columns used by callers: `sessionId`, `exerciseId`, `executada`
(bool), `cargaKg` (double?), `repsRealizadas` (int?), `criadoEm` (DateTime).

### File 2 — `lib/features/records/presentation/records_screen.dart`

The N+1 loop, lines 25–53:

```dart
final recordsProvider = FutureProvider<List<_RecordRow>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(effectiveUserIdProvider);

  // Pega todas as sessoes do user, depois todos os set_logs delas.
  final sessions = await db.sessionDao.watchByUser(userId).first;
  final sessionIds = sessions.map((s) => s.id).toSet();

  final byExercise = <String, _RecordRow>{};
  for (final s in sessions) {
    final logs = await db.setLogDao.ofSession(s.id);   // <-- N+1
    for (final l in logs) {
      if (!sessionIds.contains(l.sessionId)) continue;
      if (!l.executada) continue;
      final c = l.cargaKg ?? 0;
      final cur = byExercise[l.exerciseId];
      if (cur == null || c > cur.cargaMax) {
        byExercise[l.exerciseId] = _RecordRow(
          exerciseId: l.exerciseId,
          cargaMax: c,
          reps: l.repsRealizadas ?? 0,
          data: l.criadoEm,
        );
      }
    }
  }
  return byExercise.values.toList()
    ..sort((a, b) => b.cargaMax.compareTo(a.cargaMax));
});
```

### File 3 — `lib/features/insights/presentation/weekly_volume_screen.dart`

Lines 35–62: an inner `aggregate(from, to)` closure re-fetches **all** sessions
and queries per session; it is called twice (`atual`, `anterior`):

```dart
Future<Map<GrupoMuscular, _GroupVolume>> aggregate(
  DateTime from,
  DateTime to,
) async {
  final acc = <GrupoMuscular, _GroupVolume>{};
  final sessions = await db.sessionDao.watchByUser(userId).first;   // refetch each call
  for (final s in sessions) {
    if (s.iniciadoEm.isBefore(from) || s.iniciadoEm.isAfter(to)) continue;
    final logs = await db.setLogDao.ofSession(s.id);   // <-- N+1
    for (final l in logs) {
      if (!l.executada) continue;
      final slug = ExerciseId.parse(l.exerciseId).librarySlug;
      final ex = repo.findBySlug(slug);
      if (ex == null) continue;
      final agg = acc.putIfAbsent(
        ex.grupoPrimario,
        () => _GroupVolume(ex.grupoPrimario),
      );
      agg.volume += (l.cargaKg ?? 0) * (l.repsRealizadas ?? 0);
      agg.series += 1;
    }
  }
  return acc;
}

final atual = await aggregate(monday, now);
final anterior = await aggregate(mondayPrev, monday);
return (atual, anterior);
```

`db.sessionDao.watchByUser(userId)` returns `Stream<List<WorkoutSessionRow>>`;
`.first` reads the current snapshot. `WorkoutSessionRow` has `id` and
`iniciadoEm` (DateTime). The existing in-memory tests use
`AppDatabase.forTesting(NativeDatabase.memory())` — see `test/workout_flow_test.dart`.

## Commands you will need

| Purpose | Command (Windows local) | Expected |
|---|---|---|
| Codegen | `& 'C:\src\flutter\bin\dart.bat' run build_runner build --delete-conflicting-outputs` | exit 0 (regenerates `set_log_dao.g.dart`) |
| Analyze | `& 'C:\src\flutter\bin\flutter.bat' analyze --no-fatal-infos` | "No issues found!" |
| Test (this DAO) | `& 'C:\src\flutter\bin\flutter.bat' test test/set_log_dao_batch_test.dart` | all pass |
| Full test | `& 'C:\src\flutter\bin\flutter.bat' test` | all pass |

(CI/Linux equivalents drop the `& '...bat'` wrapper: `dart run ...`,
`flutter analyze ...`, `flutter test ...`.)

## Scope

**In scope** (modify):
- `lib/data/local/daos/set_log_dao.dart` (add one batch read method)
- `lib/features/records/presentation/records_screen.dart` (use batch method)
- `lib/features/insights/presentation/weekly_volume_screen.dart` (fetch sessions
  once, use batch method)

**In scope** (create):
- `test/set_log_dao_batch_test.dart` (new test)

**Out of scope** (do NOT touch):
- The `_RecordRow`, `_GroupVolume`, `GrupoMuscular`, `ExerciseId` types and the
  aggregation math — preserve the exact same output. Only *how* logs are fetched
  changes.
- `ofSession` (keep it; other callers use it).
- Any UI widget below the provider in these screens.

## Git workflow

- Branch: `advisor/003-batch-setlogs`
- Commit style: Conventional Commits pt-BR, e.g. `perf(history): batch de
  set_logs elimina N+1 em recordes e volume`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Add a batched read method to `SetLogDao`

In `lib/data/local/daos/set_log_dao.dart`, add this method (mirror the
`ofSession` ordering and the `markCleanAll` empty-guard):

```dart
/// Busca todos os set_logs de um conjunto de sessoes numa unica query
/// (evita N+1: antes era 1 query por sessao — ver records/weekly volume).
Future<List<SetLogRow>> ofSessions(List<String> sessionIds) {
  if (sessionIds.isEmpty) return Future.value(const []);
  return (select(setLogs)
        ..where((s) => s.sessionId.isIn(sessionIds) & s.deletedAt.isNull())
        ..orderBy([
          (s) => OrderingTerm(expression: s.ordemNoTreino),
          (s) => OrderingTerm(expression: s.numeroSerie),
        ]))
      .get();
}
```

Then regenerate code (drift needs it) and analyze.

**Verify**: codegen exits 0; `flutter analyze --no-fatal-infos` → "No issues
found!".

### Step 2: Use the batch method in `recordsProvider`

In `records_screen.dart`, replace the `for (final s in sessions) { final logs =
await db.setLogDao.ofSession(s.id); ... }` loop with a single batch fetch, then
the same in-memory grouping over all logs:

```dart
final sessions = await db.sessionDao.watchByUser(userId).first;
final sessionIds = sessions.map((s) => s.id).toSet();

final byExercise = <String, _RecordRow>{};
final logs = await db.setLogDao.ofSessions(sessionIds.toList());
for (final l in logs) {
  if (!sessionIds.contains(l.sessionId)) continue;
  if (!l.executada) continue;
  final c = l.cargaKg ?? 0;
  final cur = byExercise[l.exerciseId];
  if (cur == null || c > cur.cargaMax) {
    byExercise[l.exerciseId] = _RecordRow(
      exerciseId: l.exerciseId,
      cargaMax: c,
      reps: l.repsRealizadas ?? 0,
      data: l.criadoEm,
    );
  }
}
return byExercise.values.toList()
  ..sort((a, b) => b.cargaMax.compareTo(a.cargaMax));
```

The grouping logic is byte-for-byte the same; only the fetch changed from N
queries to 1.

**Verify**: `flutter analyze --no-fatal-infos` → "No issues found!".

### Step 3: Use the batch method in `weekly_volume_screen.dart`

Refactor so sessions are fetched **once** (not per `aggregate` call), and logs
are fetched once via `ofSessions`. Replace the `aggregate` closure + its two
calls with:

```dart
final sessions = await db.sessionDao.watchByUser(userId).first;
final sessionById = {for (final s in sessions) s.id: s};
final logs = await db.setLogDao.ofSessions(sessions.map((s) => s.id).toList());

Map<GrupoMuscular, _GroupVolume> aggregate(DateTime from, DateTime to) {
  final acc = <GrupoMuscular, _GroupVolume>{};
  for (final l in logs) {
    if (!l.executada) continue;
    final sess = sessionById[l.sessionId];
    if (sess == null) continue;
    if (sess.iniciadoEm.isBefore(from) || sess.iniciadoEm.isAfter(to)) continue;
    final slug = ExerciseId.parse(l.exerciseId).librarySlug;
    final ex = repo.findBySlug(slug);
    if (ex == null) continue;
    final agg = acc.putIfAbsent(
      ex.grupoPrimario,
      () => _GroupVolume(ex.grupoPrimario),
    );
    agg.volume += (l.cargaKg ?? 0) * (l.repsRealizadas ?? 0);
    agg.series += 1;
  }
  return acc;
}

final atual = aggregate(monday, now);
final anterior = aggregate(mondayPrev, monday);
return (atual, anterior);
```

Note `aggregate` is now synchronous (no `await` inside) — adjust the `await`s on
its call sites as shown. Keep `monday`, `mondayPrev`, `now`, `repo` exactly as
they are defined above this block.

**Verify**: `flutter analyze --no-fatal-infos` → "No issues found!".

### Step 4: Write the DAO batch test

Create `test/set_log_dao_batch_test.dart`, modeled on
`test/workout_flow_test.dart` (in-memory drift, `setUp`/`tearDown`). It must
assert that `ofSessions`:
1. returns logs from multiple sessions in one call,
2. excludes soft-deleted rows (`deletedAt` not null),
3. returns `[]` for an empty id list.

Structure:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('ofSessions retorna logs de varias sessoes numa query', () async {
    await db.sessionDao.upsert(WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'));
    await db.sessionDao.upsert(WorkoutSessionsCompanion.insert(id: 's2', userId: 'u1'));
    await db.setLogDao.upsert(SetLogsCompanion.insert(
      id: 'l1', sessionId: 's1', exerciseId: 'seed:supino_reto_barra',
      ordemNoTreino: 0, numeroSerie: 1, cargaKg: const Value(50.0)));
    await db.setLogDao.upsert(SetLogsCompanion.insert(
      id: 'l2', sessionId: 's2', exerciseId: 'seed:supino_reto_barra',
      ordemNoTreino: 0, numeroSerie: 1, cargaKg: const Value(60.0)));

    final logs = await db.setLogDao.ofSessions(['s1', 's2']);
    expect(logs.map((e) => e.id).toSet(), {'l1', 'l2'});
  });

  test('ofSessions ignora soft-deleted', () async {
    await db.sessionDao.upsert(WorkoutSessionsCompanion.insert(id: 's1', userId: 'u1'));
    await db.setLogDao.upsert(SetLogsCompanion.insert(
      id: 'l1', sessionId: 's1', exerciseId: 'seed:supino_reto_barra',
      ordemNoTreino: 0, numeroSerie: 1, cargaKg: const Value(50.0)));
    await db.setLogDao.softDelete('l1');

    final logs = await db.setLogDao.ofSessions(['s1']);
    expect(logs, isEmpty);
  });

  test('ofSessions com lista vazia retorna vazio', () async {
    expect(await db.setLogDao.ofSessions(const []), isEmpty);
  });
}
```

If `SetLogsCompanion.insert` requires additional non-nullable fields the
compiler complains about, add them following `test/workout_flow_test.dart`'s
usage (which inserts the same columns) — if a required column there isn't
obvious, STOP and report rather than guessing.

**Verify**: `flutter test test/set_log_dao_batch_test.dart` → 3 tests pass.

### Step 5: Full suite green

**Verify**: `flutter test` → all tests pass (existing 23 files + the new one).

## Test plan

- New file `test/set_log_dao_batch_test.dart`, 3 cases: multi-session batch,
  soft-delete exclusion, empty-list. Pattern source: `test/workout_flow_test.dart`.
- No UI/provider test added (the providers' output is unchanged; this is a
  fetch-shape refactor). Existing tests guard regressions.
- Verification: `flutter test` → all pass including 3 new.

## Done criteria

ALL must hold:

- [ ] `SetLogDao.ofSessions(List<String>)` exists and is generated cleanly.
- [ ] `grep -rn "setLogDao.ofSession(" lib/features/records lib/features/insights`
      returns **no** matches (both switched to `ofSessions`).
- [ ] `recordsProvider` and the weekly-volume provider issue exactly one
      `ofSessions` call each (the weekly one fetches sessions once, not per range).
- [ ] `flutter analyze --no-fatal-infos` → "No issues found!".
- [ ] `flutter test` → all pass; `test/set_log_dao_batch_test.dart` has 3 passing
      tests.
- [ ] Only the 4 in-scope files changed (`git status`).
- [ ] `plans/README.md` status row for 003 updated.

## STOP conditions

Stop and report back if:

- Any "Current state" excerpt doesn't match the live code (drift).
- `SetLogsCompanion.insert` needs columns you can't determine from
  `test/workout_flow_test.dart`.
- Changing `aggregate` to synchronous breaks a type expectation you can't
  resolve without touching out-of-scope code.
- A test fails twice after a reasonable fix attempt.

## Maintenance notes

- If `set_logs` ever gains a direct `user_id` column, `ofSessions` could become
  `ofUserBetween(userId, from, to)` and skip the session-id round trip entirely.
- Reviewer: confirm the aggregation math/output is identical to before (same
  records, same volumes) — only the query count changed. Watch the weekly screen
  still distinguishes `atual` vs `anterior` by date correctly.
- Related debt (separate finding, not in this plan): the group-by-session / Epley
  1RM aggregation is duplicated across history screens — a shared aggregator would
  build on this batch method.
