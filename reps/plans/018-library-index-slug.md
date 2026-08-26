# Plan 018: Índice slug→Exercise no LibraryRepository (elimina O(n) por linha)

## Status
- **Priority**: P2 / **Effort**: S / **Risk**: LOW / **Depends on**: none / **Category**: perf
- **Planned at**: commit `cadf58b`, 2026-07-17

## Why this matters
`findBySlug` varre linearmente ~400 exercícios (seed 100 + extended ~300) e recria
o `Exercise` via `_toExercise` (que chama `ExerciseClassifier.classificarNivel`) a
cada acerto. É chamado POR LINHA em vários builders (records, weekly_volume ×2 por
log, session_detail, routine_builder, `_WorkoutListView`). `all()` re-materializa e
concatena a lista inteira a cada chamada. Custo O(linhas × 400) por render de lista
e O(logs × 400) nas agregações. Um índice `Map<String,Exercise>` construído uma vez
torna `findBySlug` O(1) e para de realocar.

## Current state
- `lib/features/library/data/library_repository.dart`:
  - `_extended` (List<Exercise>?, carregado por `ensureLoaded`/`_loadExtended`),
    `_custom` (List<Exercise>, setado por `updateCustom`), `exercisesSeed` (const).
  - `all()` (linhas ~94–98): `[...exercisesSeed.map(_toExercise), ...ext, ..._custom]`
    — realoca a cada chamada.
  - `findBySlug` (linhas ~160–171): loop linear sobre `exercisesSeed` (com
    `_toExercise`) e depois sobre `_extended`. Retorna `Exercise?`.
  - `_toExercise(SeedRow r)` (linha ~173) converte seed→Exercise.
  - `updateCustom(List<Exercise>)` troca `_custom`.
- Padrão de teste: há `test/` com testes puros; a biblioteca é testada em
  `test/widget_test.dart` (mal nomeado — são testes da biblioteca) e
  `test/exercise_classifier_test.dart`. Use o estilo de um teste puro existente.

## Commands
| Purpose | Command | Expected |
|---|---|---|
| pub get | `C:/src/flutter/bin/flutter.bat pub get` | exit 0 |
| Format | `C:/src/flutter/bin/dart format lib/ test/` | exit 0 |
| Analyze | `C:/src/flutter/bin/flutter.bat analyze lib/features/library/` | No issues found |
| Testes | `C:/src/flutter/bin/flutter.bat test` | all pass |

## Scope
IN: `lib/features/library/data/library_repository.dart`, `test/library_index_test.dart` (create).
OUT: `exercise_thumb.dart`, telas consumidoras (a API `findBySlug`/`all` não muda de
assinatura), `.claude/settings.json`, `plans/`.

## Git
Branch `advisor/018-library-index-slug`. Commit `perf(library): indice slug->Exercise memoizado (findBySlug O(1))`. Sem push.

## Steps
### Step 1: índice memoizado
IMPORTANTE — comportamento a preservar: o `findBySlug` ATUAL busca **só seed +
extended** (`_custom` NÃO entra) e **seed vence** sobre extended. Reproduza
exatamente isso; não inclua `_custom` no índice (mudaria comportamento — se o gap
de custom é intencional ou bug, é outro plano).

Adicionar campo `Map<String, Exercise>? _bySlug;` e um getter que o constrói uma
vez a partir de extended (primeiro) + seed (por último, para sobrescrever = vencer):
```dart
  Map<String, Exercise> get _index {
    return _bySlug ??= {
      for (final e in (_extended ?? const <Exercise>[])) e.slug: e,
      for (final r in exercisesSeed) r.slug: _toExercise(r), // seed vence
    };
  }
```
`findBySlug(slug) => _index[slug];`. Invalidar (`_bySlug = null;`) ao fim de
`_loadExtended` (quando `_extended` muda). NÃO precisa invalidar em `updateCustom`
(custom não está no índice) — mas invalidar lá também é inócuo; escolha o mínimo.
`all()` continua incluindo `_custom` como hoje — NÃO mude `all()`.
**Verify**: `flutter analyze lib/features/library/` → No issues found.

### Step 2: testes
`test/library_index_test.dart`:
- `findBySlug` de um slug de seed conhecido retorna o Exercise certo (nome/slug).
- slug inexistente → null.
- um slug de `_custom` NÃO é encontrado por `findBySlug` (comportamento atual
  preservado — custom fica fora do índice).
- após `ensureLoaded()` (com o asset extended ausente em teste = `_extended` vazio),
  seed continua encontrável.
**Verify**: `flutter test test/library_index_test.dart` → all pass.

### Step 3: format + suíte
**Verify**: `dart format lib/ test/` sem diff; `flutter test` all pass (nenhuma
regressão — as telas consumidoras usam a mesma API).

## Done criteria
- [ ] `findBySlug` usa `Map` (grep por `_bySlug`/`_index`), sem loop linear
- [ ] Invalidação em `updateCustom` e no fim de `_loadExtended`
- [ ] `flutter analyze` limpo; `flutter test` all pass com teste novo
- [ ] Precedência de slug preservada (teste trava)
- [ ] Nenhum arquivo fora do escopo modificado
- [ ] Commit na branch advisor/018-*

## STOP conditions
- A precedência real do `findBySlug` atual não for "seed vence" — reproduza o que
  observar, não invente; se ambíguo, reporte.
- `all()` for usado em algum lugar que dependa de nova lista a cada chamada
  (improvável) — não altere `all()` neste plano se houver risco; foque no índice
  do `findBySlug`.
- Algum teste existente da biblioteca quebrar por causa de estado compartilhado do
  índice entre instâncias — o índice é por-instância (campo, não static); se quebrar,
  reporte.

## Maintenance notes
- Se a biblioteca virar assíncrona/paginada no futuro, o índice precisa refletir.
- Revisor: conferir que `_bySlug = null` cobre TODOS os pontos que mudam
  seed/extended/custom (hoje: `_loadExtended` e `updateCustom`).
