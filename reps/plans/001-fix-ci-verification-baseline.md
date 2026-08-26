# Plan 001: CI volta a rodar (format + codegen + .env.example) e fica verde

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 4796b7d..HEAD -- .github/workflows/ci.yml`
> If `ci.yml` changed since this plan was written, compare the "Current state"
> excerpt against the live file before proceeding; on a mismatch, treat it as a
> STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `4796b7d`, 2026-06-20

## Why this matters

CI has been **red on every recent run**. The `dart format --set-exit-if-changed`
step fails because unformatted code is committed, which causes the `analyze`,
`test`, and `build apk` steps to be **skipped**. Independently, the workflow
never runs `build_runner`, so the generated files this project depends on
(`*.g.dart` from drift / json_serializable / riverpod_generator, `*.freezed.dart`
from freezed — all gitignored) are absent in CI; even if `format` passed,
`analyze`/`test`/`build` would still fail on missing `part` files. The result:
there is no working automated safety net, and the README's claim of "flutter
analyze 0 issues, 22/22 testes passando" is only ever true locally. This plan
restores a green, trustworthy CI. It also adds the missing `.env.example` that
the workflow already tries to copy.

## Current state

- `.github/workflows/ci.yml` — the CI workflow. Steps in order: checkout,
  flutter-action (3.44.0), "Setup .env vazio para build de PR", "Garantir
  placeholders de assets", `flutter pub get`, **format check**, `flutter analyze
  --no-fatal-infos`, `flutter test`, `flutter build apk --debug`. There is **no**
  build_runner step. Current excerpt (lines 22–51):

```yaml
      - name: Setup .env vazio para build de PR
        run: |
          if [ ! -f .env ]; then
            cp .env.example .env || true
            touch .env
          fi

      - name: Garantir placeholders de assets
        run: |
          mkdir -p assets/exercises assets/templates assets/sounds assets/legal
          touch assets/exercises/.gitkeep
          touch assets/templates/.gitkeep
          touch assets/sounds/.gitkeep
          touch assets/legal/.gitkeep

      - name: pub get
        run: flutter pub get

      - name: format (somente verifica)
        run: dart format --output=none --set-exit-if-changed .

      - name: analyze
        run: flutter analyze --no-fatal-infos

      - name: test
        run: flutter test --reporter expanded

      - name: build apk debug (smoke)
        run: flutter build apk --debug
```

- Generated files are gitignored (`.gitignore` lines 26–27: `**/*.g.dart`,
  `**/*.freezed.dart`) and **not** committed (confirmed: `git ls-files` returns
  none). They must be regenerated with `build_runner` before analyze/test/build.
- `.env` is gitignored (correct) and **not** committed. `.env.example` does
  **not** exist in the repo, yet `ci.yml` references it (`cp .env.example .env`).
  The real `.env` keys (names only) are: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SENTRY_DSN`, `POSTHOG_API_KEY`, `POSTHOG_HOST`. **Never put real values in
  `.env.example` — placeholders only.**
- Toolchain note (Windows dev machine): the Flutter SDK lives at `C:\src\flutter`.
  Locally you must invoke the `.bat` wrappers and run `build_runner` **before**
  `analyze`, e.g.:
  `& 'C:\src\flutter\bin\dart.bat' run build_runner build --delete-conflicting-outputs`
  In CI (Ubuntu) the plain `dart`/`flutter` commands work.

## Commands you will need

| Purpose | Command (CI / Linux) | Local (Windows) | Expected on success |
|---|---|---|---|
| Install deps | `flutter pub get` | `& 'C:\src\flutter\bin\flutter.bat' pub get` | exit 0 |
| Codegen | `dart run build_runner build --delete-conflicting-outputs` | `& 'C:\src\flutter\bin\dart.bat' run build_runner build --delete-conflicting-outputs` | exit 0, "Succeeded" |
| Format check | `dart format --output=none --set-exit-if-changed .` | `& 'C:\src\flutter\bin\dart.bat' format --output=none --set-exit-if-changed .` | exit 0 |
| Format apply | `dart format .` | `& 'C:\src\flutter\bin\dart.bat' format .` | exit 0, lists changed files |
| Analyze | `flutter analyze --no-fatal-infos` | `& 'C:\src\flutter\bin\flutter.bat' analyze --no-fatal-infos` | exit 0, "No issues found!" |
| Test | `flutter test` | `& 'C:\src\flutter\bin\flutter.bat' test` | all pass |

## Scope

**In scope** (the only files you should modify/create):
- `.github/workflows/ci.yml` (add a build_runner step)
- `.env.example` (create)
- Any committed `*.dart` source file that `dart format .` reformats — these are
  mechanical whitespace/wrapping fixes only. **Do not** commit generated
  `*.g.dart` / `*.freezed.dart` (they are gitignored; `git add -A` already skips
  them — verify with `git status`).

**Out of scope** (do NOT touch):
- Any logic change to any `.dart` file. Formatting only — if `dart format` wants
  to change something that looks like a logic change, it won't; but if you feel
  tempted to "clean up" code, don't.
- `.env` (gitignored, never commit it).
- `analysis_options.yaml`, `pubspec.yaml`.

## Git workflow

- Branch: `advisor/001-fix-ci-baseline`
- Commit style: Conventional Commits in pt-BR (see `git log`: `ci: ...`,
  `chore: ...`). Example existing commit: `chore(supabase): script consolidado`.
- Suggested commits: (1) `chore: adiciona .env.example`, (2) `ci: gera codigo
  com build_runner antes de analyze`, (3) `chore: dart format`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create `.env.example`

Create `.env.example` in the repo root with placeholder values (NO real secrets):

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
SENTRY_DSN=
POSTHOG_API_KEY=
POSTHOG_HOST=https://us.i.posthog.com
```

**Verify**: `test -f .env.example && echo OK` → `OK`. And confirm no real
values leaked: the file contains only the placeholders above.

### Step 2: Add a build_runner step to CI, after format, before analyze

Edit `.github/workflows/ci.yml`. Insert a new step **between** the `format
(somente verifica)` step and the `analyze` step. Keeping it after `format`
means the format check still validates only hand-written code (generated files
don't exist yet at that point), and codegen runs in time for analyze/test/build.

Add exactly:

```yaml
      - name: codegen (build_runner)
        run: dart run build_runner build --delete-conflicting-outputs
```

The resulting tail of the job must read: `... format` → `codegen (build_runner)`
→ `analyze` → `test` → `build apk debug (smoke)`.

**Verify**: `grep -n "build_runner" .github/workflows/ci.yml` → one match, and
the line order is format → codegen → analyze (eyeball the file).

### Step 3: Regenerate code locally so the rest of the steps can run

Run codegen (this creates the gitignored `*.g.dart` / `*.freezed.dart`):

`dart run build_runner build --delete-conflicting-outputs`

**Verify**: command exits 0 and prints "Succeeded". Then
`flutter analyze --no-fatal-infos` → "No issues found!" (it should now resolve
the `part` files). If analyze reports real errors, that is a STOP condition.

### Step 4: Fix the formatting that CI is failing on

Run `dart format .` to apply formatting. This will reformat the committed
source files that are currently unformatted (and also the generated files, but
those are gitignored and won't be staged).

**Verify**: `dart format --output=none --set-exit-if-changed .` → exit 0
(nothing left to format). Then `git status --porcelain | grep -v '\.g\.dart\|\.freezed\.dart'`
shows only hand-written `.dart` files + `ci.yml` + `.env.example` changed.

### Step 5: Confirm the full CI sequence passes locally

Run, in order, the same commands CI runs:
1. `dart format --output=none --set-exit-if-changed .` → exit 0
2. `dart run build_runner build --delete-conflicting-outputs` → exit 0
3. `flutter analyze --no-fatal-infos` → "No issues found!"
4. `flutter test` → all tests pass

**Verify**: all four succeed. If `flutter test` has a pre-existing failure
unrelated to formatting/codegen, STOP and report it (do not try to fix test
logic — that is out of scope for this plan).

## Test plan

No new app tests in this plan — the deliverable is a working verification
pipeline, validated by the existing suite passing. After this plan, `flutter
test` (23 test files in `test/` + the existing suite) must run to completion.

## Done criteria

ALL must hold:

- [ ] `.env.example` exists with placeholder values only (no real secrets).
- [ ] `.github/workflows/ci.yml` contains a `build_runner` step located after
      the format step and before analyze (`grep -n build_runner .github/workflows/ci.yml`).
- [ ] `dart format --output=none --set-exit-if-changed .` exits 0.
- [ ] `flutter analyze --no-fatal-infos` prints "No issues found!".
- [ ] `flutter test` runs and all tests pass.
- [ ] `git status` shows no staged `*.g.dart` / `*.freezed.dart` files.
- [ ] `plans/README.md` status row for 001 updated.

## STOP conditions

Stop and report back (do not improvise) if:

- `ci.yml` doesn't match the "Current state" excerpt (CI was already changed).
- `flutter analyze` reports real code errors after codegen (not formatting) — a
  pre-existing analyze failure is a separate problem, not in this plan's scope.
- `flutter test` has a failing test unrelated to formatting/codegen.
- `build_runner` fails to generate (report the error output verbatim).
- Applying `dart format` would change a file in a way that looks like more than
  whitespace/wrapping (it shouldn't — investigate and report).

## Maintenance notes

- Reviewer: confirm the format diff is purely mechanical (whitespace, trailing
  commas, line wrapping) and that no `.g.dart`/`.freezed.dart` slipped into the
  commit.
- Follow-up deferred: CI does not run the integration test (`integration_test/
  app_test.dart` needs a device/emulator) — out of scope here; see the direction
  finding about ValueKeys.
- Once green, consider a branch-protection rule requiring CI to pass before
  merge — not in scope for this plan.
