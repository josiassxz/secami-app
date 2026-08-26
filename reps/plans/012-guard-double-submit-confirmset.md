# Plan 012: Impedir double-submit em confirmSet/skipSet (série duplicada em set_logs)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 7620a52..HEAD -- lib/features/workout/`
> ATENÇÃO: no momento em que este plano foi escrito, a working tree tinha
> mudanças NÃO COMMITADAS em `lib/features/workout/` (redesign da tela +
> `jumpToSlot`). Os excerpts abaixo refletem a working tree de 2026-07-16, não
> o commit `7620a52`. Compare com o código vivo; se os excerpts não baterem,
> STOP.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `7620a52` (+ working tree), 2026-07-16

## Why this matters

`confirmSet` lê o estado (slot atual + cursor), gera um `setLogId` novo quando
o slot ainda não tem um, e só avança o cursor DEPOIS de três `await`s (upsert
no Drift, tracking, detecção de PR). O botão "CONCLUIR SÉRIE" não é
desabilitado durante o `await`. Um toque duplo rápido executa `confirmSet`
duas vezes sobre o MESMO slot: cada invocação gera um `setLogId` diferente e
grava DUAS linhas em `set_logs` para a mesma série planejada. Histórico,
recordes, volume semanal e PR leem `set_logs` direto — a duplicata infla
volume e pode disparar PR falso, invisível na UI do treino (o cursor avança
só 1). Registrar série é a operação nº 1 do app; precisa ser idempotente.

## Current state

- `lib/features/workout/data/workout_controller.dart` — Notifier do treino
  ativo. `confirmSet` (linhas ~298–375):

  ```dart
  Future<void> confirmSet({ ... }) async {
    final s = state;
    if (s == null || s.current == null) return;
    final slot = s.current!;
    final setLogId = slot.setLogId ?? _uuid.v4();   // <- 2ª invocação gera OUTRO id
    final novo = slot.copyWith( ... setLogId: setLogId);

    await _db.setLogDao.upsert( ... );               // await #1
    await Observability.track('set_logged', ...);    // await #2
    ... await detector.detect(...);                  // await #3
    ...
    final novosSlots = [...s.slots]..[s.cursor] = novo;
    state = s.copyWith(slots: novosSlots, cursor: s.cursor + 1);  // só aqui avança
  }
  ```

  `skipSet(String motivo)` (logo abaixo, ~linhas 377–406) tem o mesmo padrão
  (await de upsert antes de avançar cursor).

- `lib/features/workout/presentation/workout_screen.dart` — a tela. `_confirm`
  (~linha 161) e `_confirmTimed`/`_skip`; o `FilledButton` "CONCLUIR SÉRIE"
  usa `onPressed: timed ? () => _confirmTimed(...) : _confirm` sem nenhum
  guard de "em andamento".

- Convenções: Riverpod `Notifier`, estado imutável via `copyWith`. Formato
  `dart format` (80 col). Comentários em pt-BR explicando o porquê.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `C:/src/flutter/bin/dart format lib/features/workout/ test/` | exit 0 |
| Analyze | `C:/src/flutter/bin/flutter.bat analyze lib/features/workout/` | No issues found |
| Testes do controller | `C:/src/flutter/bin/flutter.bat test test/workout_controller_test.dart` | all pass |
| Suíte inteira | `C:/src/flutter/bin/flutter.bat test` | all pass |

## Scope

**In scope**:
- `lib/features/workout/data/workout_controller.dart`
- `lib/features/workout/presentation/workout_screen.dart`
- `test/workout_controller_test.dart` (adicionar casos)
- `plans/README.md` (status row)

**Out of scope**:
- `lib/data/local/daos/set_log_dao.dart` — o upsert está correto; o problema
  é reentrância, não persistência.
- Deduplicação de linhas já existentes no banco (migração de dados) — fora;
  só prevenir novas duplicatas.
- `_WorkoutListView`/`jumpToSlot` — código novo vizinho, não relacionado.

## Git workflow

- Branch: `advisor/012-guard-double-submit`
- Commit: `fix(workout): impede double-submit de serie (set_log duplicado)`
- Não fazer push nem abrir PR sem instrução do operador.

## Steps

### Step 1: Guard de reentrância no controller (defesa principal)

Em `WorkoutController`, adicione um campo privado `bool _confirming = false;`
e proteja `confirmSet` E `skipSet` com early-return + `try/finally`:

```dart
  // Reentrância: um toque duplo no botão dispara confirmSet 2x sobre o mesmo
  // slot (o cursor só avança após os awaits). Sem o guard, cada invocação
  // gera um setLogId diferente => linha duplicada em set_logs, inflando
  // volume/PR. O guard torna a 2ª invocação um no-op.
  bool _confirming = false;

  Future<void> confirmSet({...}) async {
    if (_confirming) return;
    _confirming = true;
    try {
      // ...corpo atual inteiro, sem mudanças...
    } finally {
      _confirming = false;
    }
  }
```

Mesmo padrão em `skipSet`.

**Verify**: `C:/src/flutter/bin/flutter.bat analyze lib/features/workout/` →
No issues found.

### Step 2: Desabilitar o botão enquanto submete (defesa de UI)

Em `_WorkoutScreenState`, adicione `bool _submitting = false;`. Em
`_confirm`, `_confirmTimed` e `_skip`, envolva o corpo com
`setState(() => _submitting = true)` / `finally { if (mounted) setState(() => _submitting = false); }`.
No `FilledButton` (CONCLUIR SÉRIE / INICIAR) e nos `OutlinedButton` (PULAR),
use `onPressed: _submitting ? null : <handler atual>`.

Cuidado: `_confirmTimed` e `_skip` abrem overlays com `Navigator.push` —
o flag deve ser liberado no `finally` (o push interrompe o fluxo mas o
`await` retorna quando o overlay fecha; o finally cobre).

**Verify**: `C:/src/flutter/bin/flutter.bat analyze lib/features/workout/` →
No issues found.

### Step 3: Testes de regressão

Em `test/workout_controller_test.dart` (siga a estrutura dos testes
existentes no arquivo — harness com DB in-memory):

- **Caso 1 (o bug)**: iniciar treino, chamar `confirmSet(...)` DUAS vezes
  sem `await` na primeira (`unawaited(controller.confirmSet(...)); await
  controller.confirmSet(...);`), depois `await` ambas. Assert: tabela
  `set_logs` tem exatamente **1** linha para aquele slot
  (`db.setLogDao.ofSession(...)` filtrando `ordemNoTreino`/`numeroSerie`), e
  cursor avançou exatamente 1.
- **Caso 2**: `skipSet` duplo — mesma asserção (1 linha, skip único).
- **Caso 3 (não regride edição)**: confirmar série, `goBackOneSet()`,
  confirmar de novo com valores diferentes → continua 1 linha (upsert no
  mesmo `setLogId`), valores atualizados.

**Verify**: `C:/src/flutter/bin/flutter.bat test test/workout_controller_test.dart`
→ all pass, incluindo 3 novos.

### Step 4: Format + suíte completa

**Verify**: `C:/src/flutter/bin/dart format lib/features/workout/ test/ --set-exit-if-changed`
→ exit 0 (rode format antes se necessário); `C:/src/flutter/bin/flutter.bat test`
→ all pass.

## Test plan

Ver Step 3 (3 casos novos em `test/workout_controller_test.dart`, modelados
nos testes existentes do mesmo arquivo).

## Done criteria

- [ ] `flutter analyze` → 0 issues
- [ ] `flutter test` → all pass, com os 3 casos novos presentes
- [ ] `grep -n "_confirming" lib/features/workout/data/workout_controller.dart`
      encontra o guard em `confirmSet` e `skipSet`
- [ ] Botões de submit desabilitam durante `await` (grep `_submitting` na tela)
- [ ] Nenhum arquivo fora do escopo modificado (`git status`)
- [ ] `plans/README.md` status row atualizada

## STOP conditions

- Os excerpts de `confirmSet` não baterem com o código vivo (working tree
  evoluiu) — reconciliar antes de editar.
- O Caso 3 (edição via `goBackOneSet`) falhar APÓS o guard: indica que o
  guard interferiu na semântica de reconfirmação — pare e reporte, não
  contorne afrouxando o guard.
- Precisar tocar `set_log_dao.dart` para fazer o teste passar.

## Maintenance notes

- O guard `_confirming` é por-controller (o app tem um treino ativo por vez).
  Se algum dia houver múltiplos treinos simultâneos, revisitar.
- Revisor: conferir que o `finally` sempre libera os flags (senão um erro de
  DB trava o botão pra sempre).
- Duplicatas históricas pré-fix (se existirem em produção) não são tratadas
  aqui — se aparecerem reclamações de volume inflado, escrever migração de
  dedup à parte.
