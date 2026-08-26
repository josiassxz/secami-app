# Plan 004: Evitar crash em `desagrupar` quando o exercício não existe

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md` — unless a reviewer
> dispatched you and told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 4796b7d..HEAD -- lib/features/routines/data/routine_providers.dart`
> If it changed, compare the "Current state" excerpt against the live code; on a
> mismatch, STOP.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: 001 (green baseline for verification)
- **Category**: bug
- **Planned at**: commit `4796b7d`, 2026-06-20

## Why this matters

`RoutineService.desagrupar` looks up an exercise with `list.firstWhere((e) =>
e.id == reId)`. Dart's `firstWhere` **throws `StateError`** when no element
matches. If the `routine_exercise` was deleted on another device (local-first,
multi-device sync) between when the UI listed it and when the user taps
"desagrupar", `reId` won't be in `list` and the app crashes with an unhandled
exception. The fix is a null-safe lookup plus an early return — a no-op when the
row is already gone, which is the correct behavior (nothing to ungroup).

## Current state

- `lib/features/routines/data/routine_providers.dart` — defines
  `RoutineService` (a plain class taking `AppDatabase` + `userId`). Its imports
  (lines 1–11) currently do **not** include `package:collection/collection.dart`.
  `collection` **is** a declared dependency in `pubspec.yaml` (`collection:
  ^1.18.0`), so importing it is allowed without touching pubspec.
- The bug, lines 160–186:

```dart
/// Tira o exercicio do grupo. Se o grupo ficar com um unico membro, esse
/// membro tambem volta a solo (grupo de 1 nao faz sentido).
Future<void> desagrupar(String routineId, String reId) async {
  final list = await exercisesOf(routineId);
  final cur = list.firstWhere((e) => e.id == reId);   // <-- throws if not found
  final gid = cur.grupoId;
  await _db.routineDao.updateExercise(
    reId,
    const RoutineExercisesCompanion(
      grupoId: Value(null),
      grupoTipo: Value('normal'),
      rounds: Value(null),
    ),
  );
  if (gid != null) {
    final restantes = list
        .where((e) => e.grupoId == gid && e.id != reId)
        .toList();
    if (restantes.length == 1) {
      await _db.routineDao.updateExercise(
        restantes.first.id,
        const RoutineExercisesCompanion(
          grupoId: Value(null),
          grupoTipo: Value('normal'),
          rounds: Value(null),
        ),
      );
    }
  }
}
```

- The elements of `list` come from `exercisesOf(routineId)` and have `.id`,
  `.grupoId`, `.grupoTipo`, `.rounds`. The existing routine tests live in
  `test/grupo_builder_test.dart` and `test/slot_builder_test.dart`.

## Commands you will need

| Purpose | Command (Windows local) | Expected |
|---|---|---|
| Analyze | `& 'C:\src\flutter\bin\flutter.bat' analyze --no-fatal-infos` | "No issues found!" |
| Full test | `& 'C:\src\flutter\bin\flutter.bat' test` | all pass |

(CI/Linux: `flutter analyze --no-fatal-infos`, `flutter test`.)

## Scope

**In scope** (modify):
- `lib/features/routines/data/routine_providers.dart` (add import + null-safe
  lookup with early return)

**Out of scope** (do NOT touch):
- `routineDao`, `exercisesOf`, the grouping logic semantics — only the unsafe
  `firstWhere` becomes safe.
- `pubspec.yaml` (`collection` is already a dependency).
- Other `firstWhere` call sites in the file (this plan fixes only `desagrupar`;
  if you spot others, note them in your report — do not change them here).

## Git workflow

- Branch: `advisor/004-guard-desagrupar`
- Commit style: Conventional Commits pt-BR, e.g. `fix(rotinas): desagrupar nao
  crasha se exercicio ja foi removido`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Import `collection` for `firstWhereOrNull`

Add to the imports block (lines 1–11), keeping imports sorted as the file does
(package imports before relative imports):

```dart
import 'package:collection/collection.dart';
```

### Step 2: Make the lookup null-safe with an early return

Replace:

```dart
final cur = list.firstWhere((e) => e.id == reId);
final gid = cur.grupoId;
```

with:

```dart
final cur = list.firstWhereOrNull((e) => e.id == reId);
if (cur == null) return; // ja foi removido (ex.: sync de outro device)
final gid = cur.grupoId;
```

The rest of the method is unchanged.

**Verify**: `flutter analyze --no-fatal-infos` → "No issues found!".

### Step 3: Add a regression test

Create `test/desagrupar_guard_test.dart`. It must construct a `RoutineService`
against an in-memory `AppDatabase` and assert that calling `desagrupar` with an
id **not present** in the routine completes without throwing.

Inspect `routineServiceProvider` (bottom of `routine_providers.dart`, ~line 223)
to see how `RoutineService` is constructed (`RoutineService(db, userId)`), and
follow `test/workout_flow_test.dart` for the in-memory DB setup. Sketch:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/data/local/database.dart';
import 'package:reps/features/routines/data/routine_providers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('desagrupar de exercicio inexistente nao lanca', () async {
    final service = RoutineService(db, 'u1');
    await expectLater(
      service.desagrupar('rotina-qualquer', 'id-que-nao-existe'),
      completes,
    );
  });
}
```

If `RoutineService`'s constructor signature differs from `RoutineService(db,
'u1')`, adapt to the real signature shown at `routine_providers.dart:15-19` and
`:223`. If `desagrupar` needs a real routine to exist first for the test to be
meaningful, the empty-routine case already exercises the missing-id path — keep
it simple. If you cannot construct `RoutineService` without extra dependencies,
STOP and report.

**Verify**: `flutter test test/desagrupar_guard_test.dart` → passes.

### Step 4: Full suite green

**Verify**: `flutter test` → all pass.

## Test plan

- New file `test/desagrupar_guard_test.dart`: one case — `desagrupar` with a
  non-existent id completes (does not throw). Pattern: `test/workout_flow_test.dart`
  for in-memory DB.
- Verification: `flutter test` → all pass including the new case.

## Done criteria

ALL must hold:

- [ ] `routine_providers.dart` imports `package:collection/collection.dart`.
- [ ] `desagrupar` uses `firstWhereOrNull` + `if (cur == null) return;`.
- [ ] `grep -n "firstWhere((e) => e.id == reId)" lib/features/routines/data/routine_providers.dart`
      returns no match (the unsafe call is gone).
- [ ] `flutter analyze --no-fatal-infos` → "No issues found!".
- [ ] `flutter test` → all pass; new test present and passing.
- [ ] Only the in-scope file + the new test changed (`git status`).
- [ ] `plans/README.md` status row for 004 updated.

## STOP conditions

Stop and report back if:

- The `desagrupar` excerpt doesn't match the live code (drift).
- `RoutineService` can't be constructed in a test without dependencies beyond an
  `AppDatabase` + userId string.
- `collection` import triggers an analyze error (would indicate it's not actually
  resolvable — unexpected, report it).

## Maintenance notes

- Other `firstWhere` calls in the routines feature may have the same latent
  crash; this plan intentionally scopes to `desagrupar`. A sweep for
  `.firstWhere(` without an `orElse:` across `lib/features/routines/` is a
  reasonable follow-up.
- Reviewer: confirm the early return is the desired behavior (silently no-op when
  the row is already gone) — it is, because there is nothing to ungroup.
