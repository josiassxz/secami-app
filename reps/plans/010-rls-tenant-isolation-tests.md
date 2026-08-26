# Plan 010: Teste automatizado de isolamento RLS (professor↔aluno) com Postgres

> **Executor instructions**: This plan stands up test infrastructure (a real
> Postgres) — it touches CI config and adds a new test layer. Confirm the operator
> wants the CI cost before Stage 2. If a STOP condition occurs, stop and report.
>
> **Drift check (run first)**: `git diff --stat d144ad8..HEAD -- supabase/migrations/ .github/workflows/`

## Status

- **Priority**: P2 (gates coaching beta)
- **Effort**: L
- **Risk**: MED (new infra; no production code change)
- **Depends on**: 002 (the `WITH CHECK` migration — already DONE)
- **Category**: tests
- **Planned at**: commit `d144ad8`, 2026-06-21

## Why this matters

The coaching feature's multi-tenant isolation (a professor must not read/write
another professor's students' data; a professor's device must not sync a
student's private data into the professor's local Drift) is enforced **entirely**
by Postgres RLS policies in `supabase/migrations/`. None of those policies are
exercised by any automated test: `test/coach_repository_test.dart:1-6` explicitly
documents that it does **not** cover RLS — "isso exige um Postgres real e
validacao manual". A misconfigured policy (like the missing `WITH CHECK` that plan
002 just fixed) would ship undetected. This plan adds a real-Postgres test layer
that applies the migrations and asserts cross-tenant access is denied — turning a
manual, easily-skipped check into a CI gate before the coaching beta.

## Current state

- Migrations live in `supabase/migrations/0001_init.sql` … `0008_vinculos_with_check.sql`,
  applied in order. Tables with tenant RLS include `vinculos`, `convites`,
  `organizacoes`, `organizacao_membros`, plus the data tables (`workout_sessions`,
  `set_logs`, `routines`, `routine_exercises`) scoped by `auth.uid()`.
- RLS uses `auth.uid()` and helper functions (e.g. `eh_treinador_de(...)`).
- There is **no** local Postgres test harness and **no** Supabase CLI config in
  CI. `.github/workflows/ci.yml` is Flutter-only (Ubuntu).
- The existing Dart test suite uses in-memory Drift (SQLite) — it cannot exercise
  Postgres RLS (different engine, no `auth.uid()`).

## Decision the operator must make (record the answer in the PR)

This plan needs a Postgres + the ability to set the JWT/role context. Two viable
shapes — pick one before Stage 2:

- **(a) Supabase CLI local stack** (`supabase start` via Docker) in CI: most
  faithful (real GoTrue + RLS + `auth.uid()`), heavier CI (Docker, ~minutes).
- **(b) Plain Postgres (service container)** + a SQL test that `SET LOCAL role` /
  sets `request.jwt.claims` to simulate `auth.uid()`, applying the migration SQL
  directly: lighter, but you reproduce the `auth.uid()` shim yourself.

Recommendation: **(b)** for a focused RLS unit-style test (fast, no GoTrue needed);
escalate to (a) only if you later need auth/edge-function coverage too.

## Commands you will need

(Shape (b) sketch — adjust to the chosen stack.)

| Purpose | Command | Expected |
|---|---|---|
| Start PG (local) | `docker run -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:16` | container up |
| Apply migrations | `psql "$DB_URL" -f supabase/migrations/0001_init.sql` (…through 0008) | no error |
| Run RLS tests | the test runner chosen in Stage 1 (e.g. `pgTAP`, or a Dart/`psql` script) | assertions pass |

## Scope

**In scope** (create): a Postgres RLS test harness + the RLS test cases; a CI job
(or job step) that runs them. Likely new files under `supabase/tests/` (or
`test/rls/`) and an addition to `.github/workflows/` (a separate job, not the
Flutter job).
**Out of scope**: any Dart/Flutter production code; the existing Flutter CI job
(add a new job; don't entangle); changing migration SQL (002 already fixed the
known gap — this plan tests it, it doesn't edit it).

## Git workflow

- Branch: `advisor/010-rls-tests`. Commit the harness and CI job separately. Do
  NOT push.

## Steps

### Step 1: Choose the harness (record decision) and scaffold it
Pick shape (a) or (b). For (b): write a script that boots Postgres, applies
`supabase/migrations/0001..0008` in order, and provides a helper to run a query
"as" a given `auth.uid()` (set `request.jwt.claims` / `SET LOCAL`).
Consider `pgTAP` for assertions, or a thin SQL-script-per-case approach.

**Verify**: migrations apply cleanly against a fresh Postgres (no SQL error).

### Step 2: Write the cross-tenant denial test cases
At minimum, with two professors P1/P2 and two students A1 (P1's) / A2 (P2's):
1. P1 can `select` its own `vinculos`; P2 cannot see P1↔A1.
2. P1 cannot `update` a `vinculo` to reassign `aluno_id`/`professor_id` to a
   foreign user (the `WITH CHECK` from migration 0008 must deny it).
3. A student cannot read another student's `workout_sessions`/`set_logs`.
4. A professor cannot read a non-assigned student's data.

Each case asserts the denied operation returns zero rows or errors, and the
allowed operation succeeds.

**Verify**: all RLS test cases pass against the migrated schema.

### Step 3: Wire into CI as a separate job
Add a job to `.github/workflows/` (e.g. `rls`) with a Postgres service container,
that applies migrations and runs the RLS tests. Keep it independent of the Flutter
job so a Flutter failure and an RLS failure are distinguishable.

**Verify**: the job runs green locally (act/manual) or is structured to run in CI;
document any required secrets (none should be real — use a throwaway local PG).

## Test plan

- New RLS test suite (Stage 2 cases above). This is the deliverable — there is no
  "test of the test" beyond the cases asserting both allow and deny paths.
- Verification: harness applies all migrations + every RLS case passes; CI job green.

## Done criteria

- [ ] A reproducible harness applies `supabase/migrations/0001..0008` to a real
      Postgres.
- [ ] RLS test cases cover: vinculos select isolation, the 0008 `WITH CHECK`
      update denial, student↔student data isolation, professor↔non-assigned-student
      denial.
- [ ] A dedicated CI job runs them and fails on a broken policy.
- [ ] No Dart/Flutter production code changed.
- [ ] `plans/README.md` status row updated.

## STOP conditions

- The chosen harness can't faithfully simulate `auth.uid()` (revisit shape (a)).
- A migration fails to apply standalone (it may depend on Supabase-managed roles/
  extensions — note which, and which need a shim).
- CI Docker/service-container constraints block the job — report; don't hack
  around with real credentials.

## Maintenance notes

- This is the missing safety net for every future RLS change — once it exists,
  policy edits (like 002) get validated automatically.
- Reviewer: confirm the deny cases actually fail **without** the policies (e.g.
  temporarily disabling a policy should turn a deny-test red) — otherwise the test
  proves nothing.
- Pairs with the coaching go/no-go direction decision: this gate should be green
  before any coaching beta opens.
