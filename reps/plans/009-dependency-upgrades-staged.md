# Plan 009: Atualização de dependências em estágios (seguros agora, majors depois)

> **Executor instructions**: This plan is **staged**. Execute only the stage(s)
> the operator authorizes. Stage A is low-risk and self-verifying. Stages B/C are
> breaking-major migrations — do NOT start them without explicit authorization,
> and treat each as its own dispatch. If a STOP condition occurs, stop and report.
>
> **Drift check (run first)**: `git diff --stat d144ad8..HEAD -- pubspec.yaml pubspec.lock`

## Status

- **Priority**: P3
- **Effort**: Stage A = S; Stage B = L; Stage C = L
- **Risk**: Stage A = LOW; Stage B/C = HIGH
- **Depends on**: 001 (green CI baseline — already DONE)
- **Category**: dependencies
- **Planned at**: commit `d144ad8`, 2026-06-21

## Why this matters

Several core deps lag major versions: `go_router` 14→17, `flutter_riverpod`
2→3 (+ `riverpod_annotation`/`riverpod_generator`), `fl_chart` 0.68→1.x,
`sentry_flutter` 8→9. Staying behind compounds future upgrade cost (EOL, ecosystem
incompatibility). **But** these are the app's spine: routing and state management
breaking changes have runtime behavior the current suite (mostly unit/DAO tests,
few widget tests, no device E2E in CI) cannot fully validate. So this plan
separates the safe, mechanical bumps (do now) from the breaking majors (deliberate
spikes, manual QA required). For a pre-beta MVP the majors are explicitly **low
urgency** — the recommendation is Stage A now, Stages B/C only when there's
appetite for manual regression testing.

## Current state

`pubspec.yaml` pins (caret) include: `go_router: ^14.2.7`, `flutter_riverpod:
^2.5.1`, `riverpod_annotation: ^2.3.5`, `riverpod_generator: ^2.4.3`,
`fl_chart: ^0.68.0`, `sentry_flutter: ^8.7.0`, `drift: ^2.20.0`. Codegen is via
`build_runner` (riverpod_generator, drift_dev, freezed, json_serializable). CI
(`.github/workflows/ci.yml`) runs format → codegen → analyze → test → build apk.

Run `& 'C:\src\flutter\bin\flutter.bat' pub outdated` to get exact current→latest
deltas before starting (do not trust stale numbers).

## Commands you will need

| Purpose | Command (Windows local) | Expected |
|---|---|---|
| Outdated report | `& 'C:\src\flutter\bin\flutter.bat' pub outdated` | table of upgrades |
| Resolve | `& 'C:\src\flutter\bin\flutter.bat' pub get` | exit 0 |
| Codegen | `& 'C:\src\flutter\bin\dart.bat' run build_runner build --delete-conflicting-outputs` | exit 0 |
| Analyze | `& 'C:\src\flutter\bin\flutter.bat' analyze --no-fatal-infos` | "No issues found!" |
| Test | `& 'C:\src\flutter\bin\flutter.bat' test` | all pass |

## Scope

**In scope**: `pubspec.yaml`, `pubspec.lock`, and the minimum source edits a
given stage's migration guide requires.
**Out of scope**: mixing stages in one commit/branch; bumping a major not listed;
changing app behavior beyond what the migration requires.

## Git workflow

- One branch **per stage**: `advisor/009a-safe-deps`, `advisor/009b-riverpod3`,
  `advisor/009c-gorouter17`. Commit per stage. Do NOT push.

## Stage A — safe, non-breaking bumps (DO NOW if authorized)

### Step A1: Identify drop-in upgrades
From `flutter pub outdated`, select only packages whose **major version does not
change** (minor/patch within the current major): e.g. `drift`/`drift_dev` within
2.x, `sentry_flutter` only if staying within 8.x, transitive patches. Do NOT bump
`go_router`, `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`,
`fl_chart`, or `sentry_flutter` across a major in this stage.

### Step A2: Apply and verify
Update the caret pins for the selected safe packages in `pubspec.yaml`, then:
`pub get` → codegen → `analyze` → `test`.

**Verify**: all four exit clean; `flutter test` all pass. If analyze/test breaks,
the bump wasn't actually drop-in → revert that package and report.

**Done (Stage A)**: only minor/patch pins changed; analyze clean; full suite green.

## Stage B — `flutter_riverpod` 2→3 (HIGH risk; separate authorization)

Migration spike, not a mechanical edit. Riverpod 3 changes provider APIs and
codegen. Before touching code, read the official Riverpod 2→3 migration guide.
Expect changes across many providers + regenerated code. **Manual QA required**:
the unit/DAO suite will NOT catch provider-lifecycle/runtime regressions. Steps:
inventory provider usages, follow the guide package-by-package, regenerate,
analyze, test, then **manually exercise** the app (workout flow, history, routines,
coaching) before considering it done. If any provider pattern has no clean
migration, STOP and report — do not hand-roll.

## Stage C — `go_router` 14→17 (HIGH risk; separate authorization)

Routing migration. Read the go_router changelogs 15/16/17 for breaking changes
(redirect/builder signatures, `GoRouterState` API). The app's router is
`lib/core/router/app_router.dart` (+ `home_shell.dart`); there is a known
shell/dialog-pop pitfall (popping an `AlertDialog` with the wrong `context` inside
a `ShellRoute` → black screen). **Manual QA required** on every navigation path,
especially shell tabs and dialog dismissal. STOP and report if a route pattern has
no clean equivalent.

## Done criteria (per stage)

- [ ] Stage A: only non-major bumps; `analyze` clean; `flutter test` all pass;
      `pubspec.lock` updated.
- [ ] Stage B/C: migration applied per official guide; analyze clean; full suite
      green; **manual QA checklist completed and recorded in the PR description**.
- [ ] `plans/README.md` status row updated per stage.

## STOP conditions

- Any selected "safe" bump breaks analyze/test (it wasn't drop-in).
- A major migration requires a pattern the guide doesn't cover cleanly.
- `fl_chart` 0.x→1.x changes chart APIs used in `weekly_volume_screen` /
  history charts in ways that alter rendering — treat as a HIGH-risk stage of its
  own, not part of Stage A.

## Maintenance notes

- Recommendation stands: **do Stage A only before beta**; schedule B/C when there
  is time for manual regression testing. None of these block the MVP.
- Reviewer: reject any PR that bundles a major migration with unrelated changes or
  lacks the manual-QA record.
