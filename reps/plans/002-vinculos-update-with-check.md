# Plan 002: Fechar política RLS de UPDATE de `vinculos` com `WITH CHECK`

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If a
> STOP condition occurs, stop and report — do not improvise. When done, update
> the status row for this plan in `plans/README.md` — unless a reviewer
> dispatched you and told you they maintain the index.
>
> **Drift check (run first)**: `git diff --stat 4796b7d..HEAD -- supabase/migrations/`
> If migrations changed since this plan was written, re-read the latest migration
> files and confirm the `vinculos_update` policy still looks like the "Current
> state" excerpt before proceeding; on a mismatch, STOP.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (independent of 001; can land in parallel)
- **Category**: security
- **Planned at**: commit `4796b7d`, 2026-06-20

## Why this matters

The `vinculos` table models the professor↔aluno coaching relationship. Its
UPDATE Row-Level-Security policy checks identity in `USING` but has **no**
`WITH CHECK` clause, so Postgres does not constrain the *values written* by an
UPDATE — only which rows can be targeted. This is the documented RLS
anti-pattern: a state-changing policy should constrain both row selection
(`USING`) and the post-update row (`WITH CHECK`). Downstream RLS on routines /
sessions mitigates actual data theft today, and the Dart client only writes
safe columns, but the policy itself is incomplete defense-in-depth. This plan
adds the missing `WITH CHECK`, matching the pattern already used by the
`vinculos_prof_insert` policy right above it.

## Current state

- `supabase/migrations/` holds 7 numbered SQL migrations: `0001_init.sql`
  through `0007_grupo_bi_set_circuito.sql`. They are applied in order in the
  Supabase SQL Editor (per README). Migrations are **forward-only** SQL files;
  the convention is one file per change, numbered, named in pt-BR snake_case.
- The offending policy lives in `supabase/migrations/0002_coaching.sql`,
  lines 187–196:

```sql
-- vinculos: professor ve os seus, aluno ve os seus
drop policy if exists vinculos_select on public.vinculos;
create policy vinculos_select on public.vinculos for select
  using (professor_id = auth.uid() or aluno_id = auth.uid());
drop policy if exists vinculos_prof_insert on public.vinculos;
create policy vinculos_prof_insert on public.vinculos for insert
  with check (professor_id = auth.uid());
drop policy if exists vinculos_update on public.vinculos;
create policy vinculos_update on public.vinculos for update
  using (professor_id = auth.uid() or aluno_id = auth.uid());
```

Note `vinculos_update` has `using (...)` but no `with check (...)`. The INSERT
policy just above it (`vinculos_prof_insert`) correctly uses `with check`.

- **Do not edit `0002_coaching.sql`** — it has already been applied to existing
  databases. The convention is a new forward migration that redefines the
  policy. The newest existing migration is `0007`; the next number is `0008`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| List migrations | `ls supabase/migrations/` | shows new `0008_*.sql` after step 1 |
| SQL sanity (optional) | `grep -n "with check" supabase/migrations/0008_vinculos_with_check.sql` | shows the new clause |

There is no local Postgres in CI to run the SQL against (see plan-level note),
so verification here is by SQL inspection + the migration being syntactically a
straightforward `drop policy` / `create policy` pair that mirrors existing ones.

## Scope

**In scope** (only file to create):
- `supabase/migrations/0008_vinculos_with_check.sql` (create)

**Out of scope** (do NOT touch):
- `supabase/migrations/0002_coaching.sql` and every other existing migration —
  they are already applied; never rewrite history.
- Any Dart code. The client already writes only safe columns; no code change is
  needed.
- Trigger-based column immutability (locking `professor_id`/`aluno_id` from ever
  changing) — that is a larger hardening deliberately deferred; see Maintenance.

## Git workflow

- Branch: `advisor/002-vinculos-with-check`
- Commit style: Conventional Commits pt-BR. Example: `fix(supabase): WITH CHECK
  na policy de update de vinculos`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Create the forward migration `0008_vinculos_with_check.sql`

Create `supabase/migrations/0008_vinculos_with_check.sql` with exactly:

```sql
-- ============================================================
-- 0008: hardening da RLS de vinculos
-- A policy de UPDATE tinha apenas USING (selecao de linha) e nenhum
-- WITH CHECK (validacao do valor escrito). Sem WITH CHECK, um cliente que
-- passa o teste de identidade poderia gravar valores arbitrarios nas colunas.
-- Espelha o padrao ja usado em vinculos_prof_insert (migration 0002).
-- ============================================================

drop policy if exists vinculos_update on public.vinculos;
create policy vinculos_update on public.vinculos for update
  using (professor_id = auth.uid() or aluno_id = auth.uid())
  with check (professor_id = auth.uid() or aluno_id = auth.uid());
```

**Verify**: `grep -n "with check" supabase/migrations/0008_vinculos_with_check.sql`
→ one match; the `using` and `with check` predicates are identical.

### Step 2: Confirm consistency with the existing policy style

Open `supabase/migrations/0002_coaching.sql` lines 187–196 and confirm the new
0008 policy redefines `vinculos_update` with the same `using` predicate plus the
added `with check`. The `drop policy if exists` makes the migration idempotent
and safe to re-run.

**Verify**: visual diff of the two policy texts — only the added `with check`
line differs.

## Test plan

No automated test (no Postgres in CI). Validation is by SQL inspection. The
human applying migrations should, after running 0008 in the Supabase SQL Editor,
manually confirm with two accounts that an aluno/professor can still update their
own `vinculo` (e.g. accept/encerrar) and the app's coaching flow is unaffected —
this is a manual post-deploy check noted in Done criteria, not an executor step.

## Done criteria

ALL must hold:

- [ ] `supabase/migrations/0008_vinculos_with_check.sql` exists.
- [ ] It `drop policy if exists vinculos_update` then `create policy ... for
      update using (...) with check (...)` with identical predicates.
- [ ] No existing migration file was modified (`git status` shows only the new
      0008 file added).
- [ ] No `.dart` file changed.
- [ ] `plans/README.md` status row for 002 updated.
- [ ] (Manual, post-merge, by maintainer) migration applied in Supabase; coaching
      accept/encerrar flow still works for both roles.

## STOP conditions

Stop and report back if:

- The `vinculos_update` policy in `0002_coaching.sql` no longer matches the
  excerpt (a later migration may already have added `with check` — if so, this
  plan is already done; report that).
- A migration numbered `0008` already exists (pick the next free number and note
  it, or STOP if unsure).
- You find evidence the Dart client writes `professor_id`/`aluno_id` on update
  (would change the analysis) — report it.

## Maintenance notes

- **Residual gap (deliberately deferred):** `WITH CHECK (professor_id = uid OR
  aluno_id = uid)` still permits a professor to change a row's `aluno_id` to an
  arbitrary user while keeping `professor_id = self` (the check passes). Fully
  locking `professor_id`/`aluno_id` as immutable after insert requires a
  `BEFORE UPDATE` trigger comparing `OLD`/`NEW` (RLS cannot see `OLD`). That is a
  larger change; open a follow-up if the threat model requires it. This plan
  restores the baseline defense-in-depth that the missing clause removed.
- Reviewer: confirm no existing migration was edited and the predicate matches
  `USING`.
- This finding pairs with plan-level test gap "RLS / tenant isolation untestable"
  (no Postgres in CI) — a real integration harness would catch regressions here.
