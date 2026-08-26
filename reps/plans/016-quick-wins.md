# Plan 016: Quick wins — PR 0kg, leak do prStream, notificação do timer, warmupAssetCache, README

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 7620a52..HEAD -- lib/domain/usecases/pr_detector.dart lib/features/workout/ lib/features/library/presentation/exercise_thumb.dart README.md`
> Trechos abaixo refletem a working tree de 2026-07-16 (há mudanças não
> commitadas em workout/ e exercise_thumb.dart). Divergência de excerpt = STOP.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (mas execute DEPOIS de 012 se ambos rodarem — os dois
  tocam `workout_controller.dart`/tela; rebase trivial)
- **Category**: bug + dx + docs
- **Planned at**: commit `7620a52` (+ working tree), 2026-07-16

## Why this matters

Cinco defeitos pequenos, cada um S demais para plano próprio, juntos valem a
passada: banner de PR falso ("Carga máxima 0kg") na primeira série de
exercício sem carga; `StreamController` de PR nunca fechado; notificação
local do timer dispara na hora errada após ±15s/pausa; `warmupAssetCache` é
dead code cuja ausência de uso causa flash fallback→GIF nas listas; README
com instruções de setup erradas e status defasado (doc errada custa mais que
doc ausente).

## Current state

1. **PR 0kg** — `lib/domain/usecases/pr_detector.dart:54-64`:
   ```dart
   if (anteriores.isEmpty) {
     // Primeira serie do exercicio - ja eh PR de carga max e reps na carga.
     return [
       PrEvent(
         exerciseId: exerciseId,
         tipo: PrTipo.cargaMax,
         valor: cargaKg,          // <- emitido mesmo com cargaKg == 0
         ...
   ```
   Os demais ramos do arquivo já usam guardas `cargaKg > 0` — espelhar.

2. **Leak do prStream** — `lib/features/workout/data/workout_controller.dart:239-244`:
   ```dart
   class WorkoutController extends Notifier<ActiveWorkoutState?> {
     @override
     ActiveWorkoutState? build() => null;

     final _prEvents = StreamController<List<PrEvent>>.broadcast();
   ```
   Nenhum `ref.onDispose` fecha o controller.

3. **Notificação do timer** — `lib/features/workout/presentation/rest_timer_overlay.dart`:
   `initState` (linha ~38): `scheduleTimerDone(_total)`. `_adjust` (linhas
   90–95) muda `_restante`/`_total` sem reagendar; pausa idem:
   ```dart
   void _adjust(int delta) {
     setState(() {
       _restante = (_restante + delta).clamp(0, 3600);
       _total = (_total + delta).clamp(5, 3600);
     });
   }
   ```
   O mesmo padrão existe em `timed_exercise_overlay.dart` (linha ~52), que
   ainda reusa o texto "Descanso concluído — próxima série" de
   `lib/core/notifications/notification_service.dart` para um timer de
   EXECUÇÃO de série (texto semanticamente errado).

4. **warmupAssetCache morto** — `lib/features/library/presentation/exercise_thumb.dart:229-235`:
   ```dart
   Future<void> warmupAssetCache(Iterable<String> paths) async {
     for (final p in paths) {
       if (!_assetExistenceCache.containsKey(p)) {
         unawaited(_assetExists(p));
       }
     }
   }
   ```
   `grep -rn "warmupAssetCache" lib/` → só a definição. Bootstrap em
   `lib/main.dart` (~linha 146) chama `ensureLoaded()` da biblioteca mas não
   aquece as thumbs. DECISÃO deste plano: **usar** (não remover) — chamar no
   bootstrap com os assetPaths da biblioteca, elimina o flash
   fallback→imagem no primeiro render.

5. **README** — `README.md`:
   - linha ~56: "Copiar Project URL + anon key e colar em `.env`" — não
     menciona `cp .env.example .env` nem `AUTH_REDIRECT_URL` (documentada em
     `.env.example:9`).
   - linha ~70: "22/22 testes passando" — hoje são 26 arquivos / ~126+ casos.
   - linha ~71: lista "tradução slug→uuid no sync" como pendente de V1.1 —
     JÁ IMPLEMENTADA (ver `lib/core/sync/sync_engine.dart` `_exIdToDb`/
     `_loadExerciseMap`, testes `test/sync_extdb_test.dart`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `C:/src/flutter/bin/dart format lib/ test/` | exit 0 |
| Analyze | `C:/src/flutter/bin/flutter.bat analyze` | 0 erros (1 info anonKey pré-existente ok) |
| Testes | `C:/src/flutter/bin/flutter.bat test` | all pass |

## Scope

**In scope**:
- `lib/domain/usecases/pr_detector.dart` + `test/pr_detector_test.dart`
- `lib/features/workout/data/workout_controller.dart` (só o onDispose)
- `lib/features/workout/presentation/rest_timer_overlay.dart`
- `lib/features/workout/presentation/timed_exercise_overlay.dart`
- `lib/core/notifications/notification_service.dart` (parametrizar texto)
- `lib/main.dart` (chamada de warmup)
- `lib/features/library/presentation/exercise_thumb.dart` (se precisar
  expor lista de paths — provavelmente não; os paths vêm da biblioteca)
- `README.md`
- `plans/README.md` (status row)

**Out of scope**:
- `confirmSet`/`skipSet` (plano 012 é dono desses métodos)
- `sync_engine.dart` (plano 013)
- Qualquer mudança visual

## Git workflow

- Branch: `advisor/016-quick-wins`
- Um commit por item (5 commits), estilo conventional pt-BR:
  `fix(pr): nao emite PR de carga 0 na primeira serie`, etc.
- Não fazer push nem abrir PR sem instrução do operador.

## Steps

### Step 1: PR 0kg

No ramo `anteriores.isEmpty` de `detect`, retornar o `PrEvent` de `cargaMax`
apenas se `cargaKg > 0`; senão lista vazia. Adicionar caso em
`test/pr_detector_test.dart` (padrão dos casos existentes): primeira série
com `cargaKg: 0` → sem PR; com `cargaKg: 20` → PR presente (não regrediu).

**Verify**: `flutter test test/pr_detector_test.dart` → all pass.

### Step 2: fechar _prEvents

No `build()` do `WorkoutController`, registrar:
```dart
  @override
  ActiveWorkoutState? build() {
    ref.onDispose(_prEvents.close);
    return null;
  }
```

**Verify**: `flutter analyze` → 0 erros; `flutter test test/workout_controller_test.dart` → all pass.

### Step 3: reagendar notificação do timer

Em `rest_timer_overlay.dart`: no fim de `_adjust`, e no toggle de pausa,
cancelar+reagendar (`cancelTimerDone()` seguido de
`scheduleTimerDone(_restante)` quando não pausado; ao pausar, só cancelar;
ao retomar, reagendar com `_restante`). Localize o botão/handler de pausa na
própria tela (procure por `_paused`).

Em `timed_exercise_overlay.dart`: mesmo tratamento; além disso,
parametrizar `scheduleTimerDone` (em `notification_service.dart`) com
título/corpo opcionais e passar texto adequado ("Tempo concluído — registre
a série" ou similar em pt-BR) — mantenha o default atual para o descanso.

**Verify**: `flutter analyze` → 0 erros;
`flutter test test/timed_exercise_overlay_test.dart` → all pass.

### Step 4: warmup das thumbs no bootstrap

Em `lib/main.dart`, após o `ensureLoaded()` existente (~linha 146), chamar
`warmupAssetCache` com os assetPaths de todos os exercícios da biblioteca
(o repositório da biblioteca expõe `all()`; cada `Exercise` tem
`assetPath`). Import de `exercise_thumb.dart` já que a função vive lá.
`unawaited(...)` — não bloquear o boot.

**Verify**: `flutter analyze` → 0 erros;
`grep -rn "warmupAssetCache" lib/` → definição + 1 chamador.

### Step 5: README

- Passo 2 do setup: "Copiar `.env.example` para `.env` e preencher Project
  URL + anon key (e `AUTH_REDIRECT_URL` se usar confirmação por e-mail)".
- Status: trocar "22/22 testes passando" por algo estável tipo
  "`flutter analyze` 0 issues, suíte `flutter test` verde".
- Remover "tradução slug→uuid no sync" da lista V1.1 (entregue).

**Verify**: `grep -n "22/22" README.md` → sem matches.

## Test plan

- Novos: 2 casos em `pr_detector_test.dart` (Step 1).
- Regressão: suíte inteira verde.

## Done criteria

- [ ] `flutter analyze` 0 erros; `flutter test` all pass
- [ ] PR de 0kg não emitido (teste novo prova)
- [ ] `grep "onDispose(_prEvents.close)" lib/features/workout/data/workout_controller.dart` → 1 match
- [ ] `grep -rn "warmupAssetCache" lib/` → 2+ matches (def + uso)
- [ ] `grep -n "22/22" README.md` → 0 matches
- [ ] Nenhum arquivo fora do escopo modificado (`git status`)
- [ ] `plans/README.md` status row atualizada

## STOP conditions

- Excerpts não batem (drift — especialmente workout_controller, que o plano
  012 também toca; se 012 já rodou, os excerpts terão o guard `_confirming`,
  o que é ESPERADO e não é drift para este plano).
- `scheduleTimerDone` tiver assinatura incompatível com parametrização
  simples (ex.: payloads por canal) — entregue os outros itens e reporte.
- Warmup no boot degradar o startup mensuravelmente (não deve — é
  fire-and-forget) — se suspeitar, meça antes de reverter.

## Maintenance notes

- Step 3 muda contrato de `notification_service.dart` — revisor confere que
  o texto default do descanso não mudou.
- Step 4: se a biblioteca crescer muito (1000+), o warmup vira I/O de boot —
  revisitar com lazy por tela.
- README continua com contagens manuais em outros pontos — evitar números
  exatos em docs (apodrecem).
