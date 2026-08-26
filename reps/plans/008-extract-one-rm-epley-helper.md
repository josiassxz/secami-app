# Plan 008: Extrair o cálculo de 1RM (Epley) para um helper de domínio testado

> **Executor instructions**: Follow step by step. Run every verification command
> and confirm the expected result before moving on. If a STOP condition occurs,
> stop and report — do not improvise. When done, update the status row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat d144ad8..HEAD -- lib/features/history/presentation/exercise_history_screen.dart`
> If it changed, compare against the "Current state" excerpt; on a mismatch, STOP.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `d144ad8`, 2026-06-21

> **Scope note for the reviewer/maintainer:** the original audit finding
> (ARCH-05) claimed the Epley 1RM formula and group-by-session aggregation were
> duplicated across `exercise_history_screen`, `records_screen`, and
> `weekly_volume_screen`. On verification, the Epley formula appears in **exactly
> one** place (`exercise_history_screen.dart:403`), and after plan 003 the three
> screens compute genuinely different aggregates (max-load-per-exercise,
> volume-per-muscle, per-session stats) with no shared body worth consolidating.
> This plan therefore does the high-value, low-risk part only: move the magic
> 1RM formula out of the UI layer into a named, unit-tested domain function. It
> does **not** attempt a cross-screen aggregation refactor (that would be churn
> for no real duplication).

## Why this matters

The estimated-1RM formula `cargaKg * (1 + reps / 30.0)` (Epley) is hardcoded
inline inside a UI widget's private `_Stats.from`. It is a domain calculation
with a magic constant (`30.0`) and no test. Extracting it to
`lib/domain/usecases/one_rm.dart` as `oneRmEpley(...)` gives it a name, a single
source of truth if a second screen ever needs it, and a unit test pinning the
formula.

## Current state

`lib/features/history/presentation/exercise_history_screen.dart`, inside
`_Stats.from` (the loop around lines 393–410):

```dart
for (final l in group) {
  final c = unit.fromKg(l.cargaKg ?? 0);
  final r = (l.repsRealizadas ?? 0).toDouble();
  if (c > maxC) maxC = c;
  vol += c * r;
  if (c > 0 && r > 0) {
    final est = (l.cargaKg ?? 0) * (1 + r / 30.0);   // <-- Epley, inline
    if (best == null || est > best) best = est;
  }
}
```

Note the Epley input uses the **raw kg** `l.cargaKg ?? 0` (not the unit-converted
`c`), and reps `r` as a double. The extracted helper must preserve that exactly:
`oneRmEpley(l.cargaKg ?? 0, r)`. `best` accumulates the max estimate across all
logs of the exercise; `estimatedOneRm` is later displayed (line 79) and labeled
"1RM ESTIMADO (EPLEY)" (line 66).

There is no existing 1RM helper anywhere (`grep` for `/ 30` / `epley` finds only
this site). Domain helpers live in `lib/domain/usecases/` (e.g.
`progression_engine.dart`, `pr_detector.dart`). Domain tests live in `test/`
(e.g. `test/progression_engine_test.dart`).

## Commands you will need

| Purpose | Command (Windows local) | Expected |
|---|---|---|
| Analyze | `& 'C:\src\flutter\bin\flutter.bat' analyze --no-fatal-infos` | "No issues found!" |
| Helper test | `& 'C:\src\flutter\bin\flutter.bat' test test/one_rm_test.dart` | all pass |
| Full test | `& 'C:\src\flutter\bin\flutter.bat' test` | all pass |

## Scope

**In scope** (create): `lib/domain/usecases/one_rm.dart`; `test/one_rm_test.dart`.
**In scope** (modify): `lib/features/history/presentation/exercise_history_screen.dart`
(replace the inline formula with a call to the helper, add the import).
**Out of scope**: the rest of `_Stats.from` (max-load, volume, grouping — leave
exactly as-is); `records_screen.dart`, `weekly_volume_screen.dart` (no Epley
there — do NOT touch); any unit-conversion logic.

## Git workflow

- Branch: `advisor/008-one-rm-helper`.
- Commit: `refactor(history): extrai 1RM Epley para domain/usecases/one_rm`.
- Do NOT push.

## Steps

### Step 1: Create the domain helper

`lib/domain/usecases/one_rm.dart`:

```dart
/// Estimativa de 1RM pela formula de Epley: `carga * (1 + reps / 30)`.
///
/// Recebe a carga em kg (mesma unidade de armazenamento dos set_logs) e o numero
/// de repeticoes. Retorna a carga estimada para 1 repeticao, na mesma unidade da
/// entrada. Para reps <= 0 retorna a propria carga (Epley em 1 rep = carga).
double oneRmEpley(double cargaKg, double reps) {
  if (reps <= 0) return cargaKg;
  return cargaKg * (1 + reps / 30.0);
}
```

**Verify**: `flutter analyze --no-fatal-infos` → "No issues found!".

### Step 2: Use the helper in `_Stats.from`

In `exercise_history_screen.dart`, add the import (sorted with the other
`../../../domain/...` relative imports):

```dart
import '../../../domain/usecases/one_rm.dart';
```

Replace the inline line:

```dart
final est = (l.cargaKg ?? 0) * (1 + r / 30.0);
```

with:

```dart
final est = oneRmEpley(l.cargaKg ?? 0, r);
```

The surrounding `if (c > 0 && r > 0) { ... if (best == null || est > best) best = est; }`
stays unchanged. Because the guard already ensures `r > 0`, the helper's
`reps <= 0` branch won't trigger here — behavior is identical to before.

**Verify**: `flutter analyze --no-fatal-infos` → "No issues found!".

### Step 3: Unit-test the helper

`test/one_rm_test.dart`, modeled on `test/progression_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:reps/domain/usecases/one_rm.dart';

void main() {
  test('Epley: 100kg x 10 reps ~= 133.33kg', () {
    expect(oneRmEpley(100, 10), closeTo(133.333, 0.01));
  });

  test('Epley: 1 rep retorna a propria carga', () {
    expect(oneRmEpley(80, 1), closeTo(82.667, 0.01)); // 80*(1+1/30)
  });

  test('reps <= 0 retorna a carga', () {
    expect(oneRmEpley(60, 0), 60);
  });
}
```

**Verify**: `flutter test test/one_rm_test.dart` → 3 pass.

### Step 4: Full suite green

**Verify**: `flutter test` → all pass.

## Test plan

- New `test/one_rm_test.dart`: known value (100×10 → 133.33), 1-rep edge,
  zero-rep guard. Pattern: `test/progression_engine_test.dart`.
- The history screen's existing tests (if any touch `_Stats`) guard the call
  site; the computation is identical so output is unchanged.
- Verification: `flutter test` → all pass including 3 new.

## Done criteria

- [ ] `lib/domain/usecases/one_rm.dart` exists with `oneRmEpley(double, double)`.
- [ ] `exercise_history_screen.dart` imports it and calls `oneRmEpley(l.cargaKg ?? 0, r)`.
- [ ] `grep -n "/ 30.0" lib/features/history/presentation/exercise_history_screen.dart`
      returns no match (formula moved out).
- [ ] `flutter analyze --no-fatal-infos` → "No issues found!".
- [ ] `flutter test` all pass; `test/one_rm_test.dart` has 3 passing tests.
- [ ] Only the 3 in-scope files changed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- The `_Stats.from` excerpt doesn't match live code (drift).
- The displayed 1RM value would change (it must not — same formula, same inputs).
- A test fails twice after a reasonable fix.

## Maintenance notes

- If a second screen needs estimated 1RM, it now calls `oneRmEpley` — one source
  of truth. If the formula is ever swapped (e.g. Brzycki), change it here and the
  test, and all callers follow.
- Reviewer: confirm the input to `oneRmEpley` is the **raw kg** (`l.cargaKg ?? 0`),
  not the unit-converted `c` — the original used raw kg, so the helper must too.
