# Plan 007: Push de recommender_runs em batch (reusa `_pushJsons`)

> **Executor instructions**: Follow step by step. Run every verification command
> and confirm the expected result before moving on. If a STOP condition occurs,
> stop and report — do not improvise. When done, update the status row in
> `plans/README.md` unless a reviewer told you they maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat d144ad8..HEAD -- lib/core/sync/sync_engine.dart lib/data/local/daos/recommender_run_dao.dart`
> If either changed, compare against the "Current state" excerpts; on a mismatch, STOP.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `d144ad8`, 2026-06-21

## Why this matters

Every other table pushed by the sync engine goes through `_pushJsons`, which
does one batch upsert and falls back to per-row only on failure (avoiding N
HTTP round-trips). `_pushRecommenderRuns` is the exception: it loops and issues
one upsert per pending run. For a user with several queued runs this multiplies
network latency. Reusing `_pushJsons` makes recommender runs consistent with the
rest and batches the common case. Volume is low (append-only audit rows gated by
consent), so impact is modest — but it removes an inconsistency and a latent N+1.

## Current state

### File 1 — `lib/core/sync/sync_engine.dart`

The generic batch helper (lines 274–296):

```dart
Future<void> _pushJsons<T>(
  SupabaseClient client, {
  required String table,
  required List<T> rows,
  required List<Map<String, dynamic>> jsons,
  required String Function(T) id,
  required Future<void> Function(List<String>) markClean,
}) async {
  if (rows.isEmpty) return;
  try {
    await client.from(table).upsert(jsons);
    await markClean([for (final r in rows) id(r)]);
  } catch (_) {
    for (var i = 0; i < rows.length; i++) {
      try {
        await client.from(table).upsert(jsons[i]);
        await markClean([id(rows[i])]);
      } catch (e, st) {
        await Observability.captureError(e, st, hint: 'sync_push_$table');
      }
    }
  }
}
```

The per-row recommender push (lines 301–315):

```dart
Future<void> _pushRecommenderRuns(SupabaseClient client) async {
  final uid = client.auth.currentUser!.id;
  final pendentes = await _db.recommenderRunDao.pendentesSync(uid);
  // Isolamento por linha (2.4): um registro quebrado nao trava a fila.
  for (final r in pendentes) {
    try {
      await client
          .from(_tableRecommenderRuns)
          .upsert(recommenderRunToJson(r));
      await _db.recommenderRunDao.marcarSincronizado(r.id);
    } catch (e, st) {
      await Observability.captureError(e, st, hint: 'sync_push_recommender');
    }
  }
}
```

`recommenderRunToJson(r)` and the constant `_tableRecommenderRuns` already exist
and are used here. `pendentesSync(uid)` returns `List<RecommenderRunRow>`; each
row has `.id`.

### File 2 — `lib/data/local/daos/recommender_run_dao.dart` (full)

```dart
@DriftAccessor(tables: [RecommenderRuns])
class RecommenderRunDao extends DatabaseAccessor<AppDatabase>
    with _$RecommenderRunDaoMixin {
  RecommenderRunDao(super.db);

  Future<void> insert(RecommenderRunsCompanion entry) =>
      into(recommenderRuns).insert(entry);

  Stream<List<RecommenderRunRow>> watchAll(String userId) => ...;

  Future<List<RecommenderRunRow>> pendentesSync(String userId) => ...;

  Future<void> marcarSincronizado(String id) =>
      (update(recommenderRuns)..where((t) => t.id.equals(id))).write(
        const RecommenderRunsCompanion(sincronizado: Value(true)),
      );
}
```

There is a single-id `marcarSincronizado` but no batch version. The batch
pattern to mirror is `SetLogDao.markCleanAll(List<String>)` in
`lib/data/local/daos/set_log_dao.dart` (uses `..where((t) => t.id.isIn(ids))`).

## Commands you will need

| Purpose | Command (Windows local) | Expected |
|---|---|---|
| Codegen | `& 'C:\src\flutter\bin\dart.bat' run build_runner build --delete-conflicting-outputs` | exit 0 |
| Analyze | `& 'C:\src\flutter\bin\flutter.bat' analyze --no-fatal-infos` | "No issues found!" |
| DAO test | `& 'C:\src\flutter\bin\flutter.bat' test test/recommender_run_dao_test.dart` | all pass |
| Full test | `& 'C:\src\flutter\bin\flutter.bat' test` | all pass |

## Scope

**In scope** (modify): `lib/data/local/daos/recommender_run_dao.dart` (add batch
method); `lib/core/sync/sync_engine.dart` (rewrite `_pushRecommenderRuns` to use
`_pushJsons`). `test/recommender_run_dao_test.dart` (extend with a batch test).
**Out of scope**: `_pushJsons` itself (reuse, don't change); `recommenderRunToJson`,
`pendentesSync`; the pull side (recommender is push-only by design).

## Git workflow

- Branch: `advisor/007-recommender-sync-batch`.
- Commit: `perf(sync): push de recommender_runs em batch via _pushJsons`.
- Do NOT push.

## Steps

### Step 1: Add a batch markClean to `RecommenderRunDao`

Mirror `SetLogDao.markCleanAll`:

```dart
/// Marca varios runs como sincronizados numa unica query (batch — evita N+1).
Future<void> marcarSincronizadoAll(List<String> ids) async {
  if (ids.isEmpty) return;
  await (update(recommenderRuns)..where((t) => t.id.isIn(ids))).write(
    const RecommenderRunsCompanion(sincronizado: Value(true)),
  );
}
```

Regenerate code. **Verify**: codegen exit 0; `flutter analyze --no-fatal-infos`
→ "No issues found!".

### Step 2: Rewrite `_pushRecommenderRuns` to use `_pushJsons`

Replace the per-row loop with:

```dart
Future<void> _pushRecommenderRuns(SupabaseClient client) async {
  final uid = client.auth.currentUser!.id;
  final pendentes = await _db.recommenderRunDao.pendentesSync(uid);
  await _pushJsons<RecommenderRunRow>(
    client,
    table: _tableRecommenderRuns,
    rows: pendentes,
    jsons: [for (final r in pendentes) recommenderRunToJson(r)],
    id: (r) => r.id,
    markClean: (ids) => _db.recommenderRunDao.marcarSincronizadoAll(ids),
  );
}
```

If `RecommenderRunRow` is not the exact element type of `pendentesSync`'s list,
use the real type (check the DAO's return type). **Verify**:
`flutter analyze --no-fatal-infos` → "No issues found!".

### Step 3: Extend the DAO test

In `test/recommender_run_dao_test.dart`, add a test that inserts ≥2 pending runs,
calls `marcarSincronizadoAll([...])`, and asserts they are no longer returned by
`pendentesSync`. Follow the existing test structure in that file (read it first
for the insert companion shape). Also assert the empty-list case is a no-op.

**Verify**: `flutter test test/recommender_run_dao_test.dart` → all pass.

### Step 4: Full suite green

**Verify**: `flutter test` → all pass (existing sync tests still green).

## Test plan

- Extend `test/recommender_run_dao_test.dart`: `marcarSincronizadoAll` marks
  multiple rows synced (they drop out of `pendentesSync`); empty list is a no-op.
- The behavior of `_pushRecommenderRuns` is covered structurally by reusing the
  already-tested `_pushJsons` path; no network test added.
- Verification: `flutter test` → all pass.

## Done criteria

- [ ] `RecommenderRunDao.marcarSincronizadoAll(List<String>)` exists, generated
      cleanly.
- [ ] `_pushRecommenderRuns` contains no `for (` loop and calls `_pushJsons`.
- [ ] `grep -n "marcarSincronizado(" lib/core/sync/sync_engine.dart` returns no
      match (the old per-row call is gone).
- [ ] `flutter analyze --no-fatal-infos` → "No issues found!".
- [ ] `flutter test` all pass; new DAO test passes.
- [ ] Only the 3 in-scope files changed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- Excerpts don't match live code (drift).
- `pendentesSync` element type isn't determinable for the `_pushJsons<T>` type arg.
- A test fails twice after a reasonable fix.

## Maintenance notes

- The per-row fallback semantics ("isolamento por linha") are preserved by
  `_pushJsons` — a single bad row no longer blocks the queue; it stays unsynced
  and retries next cycle. Reviewer: confirm the consent gate (`sincronizavel`)
  still scopes `pendentesSync` (unchanged here).
- If recommender ever needs a pull side, this batch push is the template.
