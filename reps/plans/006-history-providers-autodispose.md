# Plan 006: `.autoDispose` nos providers `.family` de histórico

> **Executor instructions**: Follow step by step. Run every verification command
> and confirm the expected result before moving on. If a STOP condition occurs,
> stop and report — do not improvise. When done, update the status row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat d144ad8..HEAD -- lib/features/history/data/history_providers.dart`
> If it changed, compare against the "Current state" excerpt; on a mismatch, STOP.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `d144ad8`, 2026-06-21

## Why this matters

`FutureProvider.family` / `StreamProvider.family` without `.autoDispose` cache
one result per distinct argument **forever**. As the user navigates to many
sessions/exercises, the Riverpod cache grows unbounded for data that is only
needed while a detail screen is open. The rest of the codebase already uses
`autoDispose` for the equivalent case (`exerciseInsightProvider` in
`lib/features/workout/data/progression_providers.dart` is a
`FutureProvider.autoDispose`). This aligns the history providers with that
convention. Behavior is unchanged except that cached entries are freed when no
widget is listening.

## Current state

`lib/features/history/data/history_providers.dart` (full file):

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';
import '../../../data/local/database.dart';
import '../../auth/data/auth_providers.dart';

final sessionsStreamProvider = StreamProvider<List<WorkoutSessionRow>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final userId = ref.watch(effectiveUserIdProvider);
  return db.sessionDao.watchByUser(userId);
});

final sessionByIdProvider = FutureProvider.family<WorkoutSessionRow?, String>((
  ref,
  id,
) {
  return ref.watch(appDatabaseProvider).sessionDao.findById(id);
});

final setLogsOfSessionProvider = StreamProvider.family<List<SetLogRow>, String>(
  (ref, sessionId) {
    return ref.watch(appDatabaseProvider).setLogDao.watchOfSession(sessionId);
  },
);

final setLogsOfExerciseProvider =
    FutureProvider.family<List<SetLogRow>, String>((ref, exerciseId) {
      return ref.watch(appDatabaseProvider).setLogDao.ofExercise(exerciseId);
    });
```

The three `.family` providers (`sessionByIdProvider`, `setLogsOfSessionProvider`,
`setLogsOfExerciseProvider`) get `.autoDispose`. The non-family
`sessionsStreamProvider` stays as-is (it backs the main history list that is
always present while the feature is open — leave it).

## Commands you will need

| Purpose | Command (Windows local) | Expected |
|---|---|---|
| Analyze | `& 'C:\src\flutter\bin\flutter.bat' analyze --no-fatal-infos` | "No issues found!" (1 pre-existing info OK) |
| Full test | `& 'C:\src\flutter\bin\flutter.bat' test` | all pass |

## Scope

**In scope** (modify): `lib/features/history/data/history_providers.dart`.
**Out of scope**: `sessionsStreamProvider` (leave non-family as-is); every call
site of these providers (`.family` + `.autoDispose` does not change how they are
read with `ref.watch(provider(arg))`); any other file.

## Git workflow

- Branch: `advisor/006-history-autodispose` (a reviewer will create/checkout it
  for you if running non-isolated; otherwise create it).
- Commit: `refactor(history): autoDispose nos providers family`.
- Do NOT push.

## Steps

### Step 1: Add `.autoDispose` to the three family providers

Change each `.family` to `.autoDispose.family`:

- `sessionByIdProvider`: `FutureProvider.autoDispose.family<WorkoutSessionRow?, String>(...)`
- `setLogsOfSessionProvider`: `StreamProvider.autoDispose.family<List<SetLogRow>, String>(...)`
- `setLogsOfExerciseProvider`: `FutureProvider.autoDispose.family<List<SetLogRow>, String>(...)`

The provider bodies are unchanged.

**Verify**: `flutter analyze --no-fatal-infos` → "No issues found!" (the single
pre-existing `anonKey` info in `lib/core/config/supabase_client.dart` is
acceptable). If analyze reports an error at any call site, STOP and report it.

### Step 2: Full suite green

**Verify**: `flutter test` → all pass (no behavior change expected).

## Test plan

No new test: this is a caching-lifecycle change with no observable behavior
difference a unit test could assert meaningfully. The existing suite guards
against call-site breakage.

## Done criteria

- [ ] All three `.family` providers in `history_providers.dart` are
      `.autoDispose.family`.
- [ ] `grep -c "autoDispose.family" lib/features/history/data/history_providers.dart`
      returns 3.
- [ ] `sessionsStreamProvider` is unchanged.
- [ ] `flutter analyze --no-fatal-infos` → "No issues found!".
- [ ] `flutter test` all pass.
- [ ] Only `history_providers.dart` changed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- The file doesn't match the "Current state" excerpt (drift).
- `flutter analyze` reports a real error at a call site (some code may depend on
  the provider's value surviving navigation — report it; do not force it).
- `flutter test` regresses.

## Maintenance notes

- Reviewer: confirm no screen relies on these caches persisting across
  navigation (none should — they re-fetch from Drift, which is local and fast).
- If a future screen needs a history result kept alive deliberately, use
  `ref.keepAlive()` at that call site rather than removing `autoDispose` here.
