# Plan 013: Status de sync honesto (pendingPush real + falhas por linha visíveis) com testes de runOnce

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 7620a52..HEAD -- lib/core/sync/ test/`
> ATENÇÃO: quando este plano foi escrito, `lib/core/sync/sync_engine.dart` e
> `sync_providers.dart` tinham mudanças NÃO COMMITADAS (guard `_inFlight`,
> replay do status, push por ids). Os excerpts refletem a working tree de
> 2026-07-16. Se não baterem com o código vivo, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none (mas commitar a working tree atual antes ajuda o drift check)
- **Category**: bug + tests
- **Planned at**: commit `7620a52` (+ working tree), 2026-07-16

## Why this matters

Duas mentiras no status de sync: (1) ao final de um `runOnce` bem-sucedido, o
engine emite `pendingPush: 0` **fixo**, sem recontar o dirty real; (2) o
fallback por linha de `_pushJsons` engole toda falha individual (só
`captureError`), então uma linha permanentemente rejeitada pelo servidor
(constraint, validação) deixa o ciclo terminar "com sucesso". Combinadas: a
UI (tile de Ajustes) mostra "Tudo sincronizado" com 0 pendentes enquanto
linhas seguem `dirty=1` para sempre. O usuário não tem nenhum sinal. Além
disso, o comportamento novo do engine (aguardar sync em andamento; replay do
status no provider) não tem nenhum teste — regressões seriam invisíveis.

## Current state

- `lib/core/sync/sync_engine.dart` — o motor. Pontos relevantes:

  Fim do `runOnce` (sucesso), ~linhas 118–126:
  ```dart
      await _emit(
        _status.copyWith(
          phase: SyncPhase.idle,
          lastSuccessAt: DateTime.now().toUtc(),
          pendingPush: 0,                     // <- fixo, mente se sobrou dirty
        ),
      );
  ```

  Já existe um contador real, `_refreshPendingCount()` (~linhas 145–153):
  ```dart
  Future<void> _refreshPendingCount() async {
    var pending = 0;
    pending += (await _db.routineDao.dirtyRoutines()).length;
    ... (5 tabelas)
    await _emit(_status.copyWith(pendingPush: pending));
  }
  ```

  `_pushJsons` (~linhas 288–309) — fallback por linha engole falhas:
  ```dart
    } catch (_) {
      for (var i = 0; i < jsons.length; i++) {
        try {
          await client.from(table).upsert(jsons[i]);
          await markClean([ids[i]]);
        } catch (e, st) {
          await Observability.captureError(e, st, hint: 'sync_push_$table');
        }
      }
    }
  ```

  Guard de concorrência (`runOnce` topo): `if (_running) { await _inFlight; return; }`
  com `Completer` setado em `try/finally`.

- `lib/core/sync/sync_providers.dart` — provider com replay:
  ```dart
  final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
    final engine = ref.watch(syncEngineProvider);
    yield engine.status;
    yield* engine.statusStream;
  });
  ```

- `lib/core/sync/sync_status.dart` — `SyncStatus` imutável com `copyWith`
  (campos: phase, lastSuccessAt, lastError, pendingPush).

- `lib/features/settings/presentation/settings_screen.dart` — `_syncSubtitle`
  monta "Última: dd/MM HH:mm · N pendente(s)" a partir de `s.pendingPush`, e
  `_syncNow` decide o snackbar por `s.phase == SyncPhase.error || s.lastError != null`.

- Testes de sync existentes (padrão a seguir): `test/sync_cursor_test.dart`,
  `test/sync_owner_filter_test.dart`, `test/sync_extdb_test.dart` — usam stubs
  de `http.BaseClient` (`_StubClient`/`_CapturingClient`) injetados no
  `SupabaseClient`, e o DB Drift in-memory. **Leia um deles inteiro antes de
  escrever testes** — é o padrão do repo (testa lógica real, não mocks do
  engine).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `C:/src/flutter/bin/dart format lib/core/sync/ test/` | exit 0 |
| Analyze | `C:/src/flutter/bin/flutter.bat analyze lib/core/sync/` | No issues found |
| Testes sync | `C:/src/flutter/bin/flutter.bat test test/sync_cursor_test.dart test/sync_owner_filter_test.dart test/sync_extdb_test.dart test/sync_batch_clean_test.dart test/sync_mappers_roundtrip_test.dart` | all pass |
| Suíte | `C:/src/flutter/bin/flutter.bat test` | all pass |

## Scope

**In scope**:
- `lib/core/sync/sync_engine.dart`
- `test/sync_run_once_test.dart` (create)
- `plans/README.md` (status row)

**Out of scope**:
- `lib/core/sync/sync_providers.dart` — o replay está correto; só ganha teste
  se o harness permitir sem retrabalho (opcional, ver Step 4).
- `lib/features/settings/presentation/settings_screen.dart` — a UI já lê
  `pendingPush`; nenhuma mudança necessária.
- Retry/backoff por linha — tradeoff aceito (registrado em plans/README.md,
  "Findings considered and rejected"); NÃO adicionar backoff.
- `_pullTable`/cursor — funciona e tem teste; não tocar.

## Git workflow

- Branch: `advisor/013-sync-status-honesto`
- Commit: `fix(sync): pendingPush real no fim do runOnce e falha por linha visivel`
- Não fazer push nem abrir PR sem instrução do operador.

## Steps

### Step 1: Contar falhas por linha em `_pushJsons`

Mude `_pushJsons` para retornar o número de linhas que FALHARAM no fallback:

```dart
  /// Retorna o numero de linhas que falharam no push (0 = tudo subiu).
  Future<int> _pushJsons(...) async {
    if (jsons.isEmpty) return 0;
    try {
      await client.from(table).upsert(jsons);
      await markClean(ids);
      return 0;
    } catch (_) {
      var falhas = 0;
      for (var i = 0; i < jsons.length; i++) {
        try { ... } catch (e, st) {
          falhas++;
          await Observability.captureError(e, st, hint: 'sync_push_$table');
        }
      }
      return falhas;
    }
  }
```

Propague: `_pushTable` e `_pushRecommenderRuns` retornam o valor; `_pushAll`
soma e retorna o total de falhas do ciclo.

**Verify**: `C:/src/flutter/bin/flutter.bat analyze lib/core/sync/` → No issues.

### Step 2: `runOnce` emite pendência real

No sucesso do `runOnce`, troque o literal `pendingPush: 0` por uma recontagem
real. Refatore `_refreshPendingCount()` para separar contagem de emissão:

```dart
  Future<int> _countPending() async {
    var pending = 0;
    pending += (await _db.routineDao.dirtyRoutines()).length;
    // ... 5 tabelas, igual ao corpo atual de _refreshPendingCount
    return pending;
  }
```

E no fim do `runOnce`:

```dart
      final falhasPush = ... // vindo do _pushAll (Step 1)
      final pendentes = await _countPending();
      await _emit(
        _status.copyWith(
          phase: SyncPhase.idle,
          lastSuccessAt: DateTime.now().toUtc(),
          pendingPush: pendentes,
          // Falha por linha nao derruba o ciclo, mas nao pode sumir do
          // status: lastError sinaliza que ha linha presa (UI mostra aviso).
          lastError: falhasPush > 0
              ? '$falhasPush registro(s) nao subiram; ficam pendentes'
              : null,
          clearError: falhasPush == 0,
        ),
      );
```

`_refreshPendingCount()` original vira `_emit(_status.copyWith(pendingPush: await _countPending()))`.

**Verify**: `analyze` limpo + os 5 arquivos de teste de sync existentes
continuam verdes (`flutter test test/sync_*.dart`).

### Step 3: Testes de `runOnce` (arquivo novo `test/sync_run_once_test.dart`)

Modele no padrão de `test/sync_owner_filter_test.dart` (stub de
`http.BaseClient` + Drift in-memory + SupabaseClient apontando pro stub).
Casos:

1. **pendingPush honesto**: semear 2 rotinas dirty; stub responde erro no
   upsert em batch E por linha (ex.: 400) → após `runOnce`, `engine.status.pendingPush == 2`
   e `lastError != null`. (Antes do fix daria 0/null — este é o teste de
   regressão do bug.)
2. **sucesso real zera**: stub responde 200/201 para tudo → `pendingPush == 0`,
   `lastError == null`, `lastSuccessAt != null`.
3. **concorrência `_inFlight`**: stub com atraso artificial (Completer no
   send); disparar `runOnce()` duas vezes — a 2ª só resolve depois da 1ª, e o
   stub registrou UM ciclo de push (contagem de requests).
4. **retry agendado em erro**: stub que lança em tudo → status final
   `phase == SyncPhase.error`, `lastError != null`. (Não teste o Timer real —
   só o estado emitido.)

Se autenticação for problema no harness: os testes existentes já resolvem
isso (veja como `sync_owner_filter_test.dart` cria o client com sessão) —
copie a abordagem.

**Verify**: `C:/src/flutter/bin/flutter.bat test test/sync_run_once_test.dart`
→ 4 casos passam.

### Step 4 (opcional, só se trivial): teste do replay do provider

`ProviderContainer` + engine com status pré-setado → primeiro evento de
`syncStatusProvider` é o status atual. Se exigir mock do Supabase init além
do que o harness dos outros testes oferece, PULE e registre como deferido.

**Verify**: `flutter test` completo → all pass.

## Test plan

Ver Step 3 (4 casos novos) + Step 4 opcional. Padrão estrutural:
`test/sync_owner_filter_test.dart`.

## Done criteria

- [ ] `grep -n "pendingPush: 0" lib/core/sync/sync_engine.dart` → nenhuma
      ocorrência no caminho de sucesso do runOnce (literal substituído por
      contagem)
- [ ] `_pushJsons` retorna `Future<int>` (falhas) — grep confirma assinatura
- [ ] `flutter analyze` → 0 issues
- [ ] `flutter test` → all pass, incluindo `test/sync_run_once_test.dart` novo
- [ ] Nenhum arquivo fora do escopo modificado (`git status`)
- [ ] `plans/README.md` status row atualizada

## STOP conditions

- Excerpts do `runOnce`/`_pushJsons` não baterem com o código vivo.
- O harness de teste não conseguir injetar client autenticado sem mudanças em
  `lib/` (produção não pode mudar por causa de teste — reporte).
- O Caso 3 (concorrência) se mostrar flaky após 2 tentativas de estabilizar —
  entregue os outros casos e registre o 3 como deferido, não invente sleeps.

## Maintenance notes

- A UI de Ajustes passa a mostrar "N pendente(s)" quando há linha presa —
  comportamento novo visível; revisor deve conferir a string pt-BR.
- Se um dia adicionarem fila de mortos (dead-letter) para linhas rejeitadas,
  o contador de falhas do Step 1 é o gancho.
- O texto de `lastError` do Step 2 aparece no banner OFFLINE do topo
  (home_shell) — verificar que não é enganoso nesse contexto (banner diz
  "toque para sincronizar"; re-sincronizar não resolve linha presa, mas
  também não piora).
