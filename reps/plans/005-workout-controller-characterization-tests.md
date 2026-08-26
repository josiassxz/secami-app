# Plan 005: Testes de caracterização do WorkoutController (loop central do treino)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md` — unless a reviewer
> dispatched you and told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 4796b7d..HEAD -- lib/features/workout/data/workout_controller.dart`
> If it changed, compare the "Current state" excerpts against the live code; on a
> mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW (adds tests only; no production code change)
- **Depends on**: 001 (green baseline). Should land **before** any refactor of
  the workout feature.
- **Category**: tests
- **Planned at**: commit `4796b7d`, 2026-06-20

## Why this matters

`WorkoutController` is the core "modo treino" execution loop — the feature the
app exists for ("registrar uma série leva no máximo 2 toques"). Its key methods
(`startFromRoutine`, `confirmSet`, `skipSet`) are exercised only indirectly
through widget/DB integration tests; there is **no** direct unit test of the
state transitions, set-log persistence, or cursor advancement. The file is high
churn (8–9 recent commits). Characterization tests lock in the current correct
behavior so future refactors (e.g. splitting the god-screen) can't silently
regress set logging or cursor movement. This plan adds tests only — it changes
no production code.

## Current state

- `lib/features/workout/data/workout_controller.dart` — `WorkoutController
  extends Notifier<ActiveWorkoutState?>` (line 239). Registered as
  `workoutControllerProvider` (line 514). Key facts:

```dart
// line 239
class WorkoutController extends Notifier<ActiveWorkoutState?> {
  @override
  ActiveWorkoutState? build() => null;
  ...
  AppDatabase get _db => ref.read(appDatabaseProvider);          // line 246
  String get _userId => ref.read(effectiveUserIdProvider);       // line 247

  Future<String> startFromRoutine(String routineId) async { ... } // line 264
  Future<void> confirmSet({                                        // line 298
    int? repsRealizadas,
    required double cargaKg,
    int? rpe,
    int? duracaoSegundos,
  }) async { ... state = s.copyWith(slots: novosSlots, cursor: s.cursor + 1); }

  Future<void> skipSet(String motivo) async { ... }               // line 377
}
```

- `confirmSet` (lines 298–375): if `state` or `state.current` is null it returns
  early; otherwise it builds a `setLogId`, upserts a `SetLogsCompanion` into
  `setLogDao` with `executada: true`, runs PR detection, updates the slot, and
  advances `cursor` by 1.
- `skipSet` (lines 377–405): upserts a set_log with `executada: false` and
  `motivoPulo`, advances `cursor` by 1.
- `startFromRoutine` (lines 264–296): reads `routineServiceProvider` to load the
  routine + its exercises, inserts a `WorkoutSessionsCompanion`, builds slots,
  sets `state`, returns the new `sessionId`.

### Providers the controller depends on (for test overrides)

All are plain `Provider`s (not async), so overriding the two leaf providers is
enough — the rest resolve through them against the in-memory DB:

- `appDatabaseProvider` — `lib/core/sync/sync_providers.dart:11`,
  `Provider<AppDatabase>`. **Override with an in-memory test DB.**
- `effectiveUserIdProvider` — `lib/features/auth/data/auth_providers.dart:38`,
  `Provider<String>`. **Override with a fixed `'u1'`.**
- `routineServiceProvider` — `lib/features/routines/data/routine_providers.dart:223`
  — reads `appDatabaseProvider` + `effectiveUserIdProvider`; resolves fine once
  those are overridden.
- `prDetectorProvider` — `lib/domain/usecases/pr_detector.dart:174` — likewise
  reads the DB. No override needed.

`Observability.track(...)` is a static no-op when analytics keys are absent
(test env), so it needs no mocking.

### Test infrastructure that already exists

`test/workout_flow_test.dart` uses `AppDatabase.forTesting(NativeDatabase.memory())`
and seeds sessions/set_logs directly via DAOs. Reuse that DB setup. To drive a
`Notifier`, build a `ProviderContainer` with overrides and read
`container.read(workoutControllerProvider.notifier)`.

To seed a routine for `startFromRoutine`, insert via the DAOs the routine + its
routine_exercises. Inspect `RoutineService` / `routineDao` in
`lib/features/routines/data/routine_providers.dart` and `lib/data/local/daos/`
to find the exact insert companions (e.g. `RoutinesCompanion.insert`,
`RoutineExercisesCompanion.insert`) and required columns. **If the routine seed
shape is not determinable from those files, STOP and report** rather than
guessing column names.

## Commands you will need

| Purpose | Command (Windows local) | Expected |
|---|---|---|
| Codegen | `& 'C:\src\flutter\bin\dart.bat' run build_runner build --delete-conflicting-outputs` | exit 0 |
| Analyze | `& 'C:\src\flutter\bin\flutter.bat' analyze --no-fatal-infos` | "No issues found!" |
| This test | `& 'C:\src\flutter\bin\flutter.bat' test test/workout_controller_test.dart` | all pass |
| Full test | `& 'C:\src\flutter\bin\flutter.bat' test` | all pass |

(CI/Linux: drop the `& '...bat'` wrapper.)

## Scope

**In scope** (create):
- `test/workout_controller_test.dart` (new)

**Out of scope** (do NOT modify):
- **Any** file under `lib/`. This plan adds tests only. If a method appears
  genuinely untestable without a production change (e.g. a hard dependency that
  can't be overridden), STOP and report — do not refactor production code here.
- `finish()` and health integration (`healthIntegrationProvider`) — not covered
  by this plan (needs more setup; deferred).

## Git workflow

- Branch: `advisor/005-workout-controller-tests`
- Commit style: Conventional Commits pt-BR, e.g. `test(workout): caracteriza
  confirmSet/skipSet/startFromRoutine`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Scaffold the test file with container + overrides

Create `test/workout_controller_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/core/sync/sync_providers.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/features/auth/data/auth_providers.dart';
import 'package:reps/features/workout/data/workout_controller.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      effectiveUserIdProvider.overrideWithValue('u1'),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  // tests below
}
```

If `appDatabaseProvider` / `effectiveUserIdProvider` are not exported from the
import paths above, find their real locations (they are at
`lib/core/sync/sync_providers.dart:11` and
`lib/features/auth/data/auth_providers.dart:38`) and import accordingly.

**Verify**: file compiles — `flutter analyze --no-fatal-infos` → "No issues
found!".

### Step 2: Test `startFromRoutine` seeds a session and slots

Seed a routine + at least one routine_exercise via the DAOs (see "Current
state" guidance), then:

```dart
test('startFromRoutine cria sessao e popula slots', () async {
  // ... seed routine 'r1' with one exercise via DAOs ...
  final controller = container.read(workoutControllerProvider.notifier);
  final sessionId = await controller.startFromRoutine('r1');

  expect(sessionId, isNotEmpty);
  final state = container.read(workoutControllerProvider);
  expect(state, isNotNull);
  expect(state!.sessionId, sessionId);
  expect(state.cursor, 0);
  expect(state.slots, isNotEmpty);

  // sessao persistida
  final sess = await db.sessionDao.findById(sessionId);
  expect(sess, isNotNull);
});
```

**Verify**: `flutter test test/workout_controller_test.dart` → this test passes.

### Step 3: Test `confirmSet` persists a set_log and advances the cursor

After `startFromRoutine`, call `confirmSet` and assert: (a) a `set_log` row with
`executada == true` and the given `cargaKg` was written for the current session,
(b) the state cursor advanced by 1, (c) the slot is marked completed.

```dart
test('confirmSet grava set_log executada e avanca cursor', () async {
  // ... seed + startFromRoutine, capture sessionId ...
  final controller = container.read(workoutControllerProvider.notifier);
  final before = container.read(workoutControllerProvider)!;
  await controller.confirmSet(repsRealizadas: 10, cargaKg: 50.0);

  final after = container.read(workoutControllerProvider)!;
  expect(after.cursor, before.cursor + 1);

  final logs = await db.setLogDao.ofSession(after.sessionId);
  expect(logs.where((l) => l.executada).length, 1);
  expect(logs.first.cargaKg, 50.0);
  expect(logs.first.repsRealizadas, 10);
});
```

**Verify**: this test passes.

### Step 4: Test `skipSet` persists a not-executed log with motive and advances

```dart
test('skipSet grava set_log nao executada com motivo e avanca cursor', () async {
  // ... seed + startFromRoutine ...
  final controller = container.read(workoutControllerProvider.notifier);
  final before = container.read(workoutControllerProvider)!;
  await controller.skipSet('equipamento_ocupado');

  final after = container.read(workoutControllerProvider)!;
  expect(after.cursor, before.cursor + 1);

  final logs = await db.setLogDao.ofSession(after.sessionId);
  final skipped = logs.firstWhere((l) => !l.executada);
  expect(skipped.motivoPulo, 'equipamento_ocupado');
});
```

**Verify**: this test passes.

### Step 5: Test the early-return guard

`confirmSet` returns early when there is no active state. Assert calling it
before `startFromRoutine` does nothing (no throw, no log, state stays null):

```dart
test('confirmSet sem sessao ativa e no-op', () async {
  final controller = container.read(workoutControllerProvider.notifier);
  await controller.confirmSet(cargaKg: 40.0); // no active state
  expect(container.read(workoutControllerProvider), isNull);
});
```

**Verify**: this test passes.

### Step 6: Full suite green

**Verify**: `flutter test` → all pass (existing + the new file's ~5 tests).

## Test plan

- New file `test/workout_controller_test.dart`, ~5 cases: `startFromRoutine`
  seeds session+slots; `confirmSet` persists executed log + advances cursor;
  `skipSet` persists skipped log with motive + advances cursor; early-return
  guard. Pattern source: `test/workout_flow_test.dart` (in-memory DB) + Riverpod
  `ProviderContainer` overrides.
- Each assertion checks a real observable (DB row, state field) — no
  assert-nothing tests.
- Verification: `flutter test` → all pass.

## Done criteria

ALL must hold:

- [ ] `test/workout_controller_test.dart` exists with at least 4 meaningful
      tests (startFromRoutine, confirmSet, skipSet, guard).
- [ ] Each test asserts a concrete observable (persisted set_log fields and/or
      `cursor` advancement), not just "no throw" (except the guard test).
- [ ] `flutter analyze --no-fatal-infos` → "No issues found!".
- [ ] `flutter test` → all pass.
- [ ] **No file under `lib/` was modified** (`git status` shows only the new test
      file).
- [ ] `plans/README.md` status row for 005 updated.

## STOP conditions

Stop and report back if:

- The controller method signatures don't match the "Current state" excerpts.
- A routine can't be seeded via DAOs without information not present in
  `routine_providers.dart` / the DAOs.
- `confirmSet`/`skipSet`/`startFromRoutine` can't be driven without overriding a
  provider beyond `appDatabaseProvider` + `effectiveUserIdProvider` (e.g. one
  reaches into Supabase/network) — report which provider blocks it.
- Any test would require modifying production code to pass.

## Maintenance notes

- These are **characterization** tests: they encode current behavior, not a
  spec. If a future change intentionally alters cursor logic or log fields, the
  test updates alongside it — that's expected, and the test failure is the signal
  to review the change.
- Deferred (not in this plan): `finish()` + health integration, `substituteCurrent`,
  `goBackOneSet`/`jumpToNextExercise`. Good follow-up once this scaffold exists.
- Reviewer: confirm the tests assert real persisted values, and that no `lib/`
  file sneaked into the diff.
