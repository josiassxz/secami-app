# Plan 015: client_logs sem PII e com retenção (redação na origem + TTL no banco + testes)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 7620a52..HEAD -- lib/core/logging/ supabase/migrations/`
> ATENÇÃO: `lib/core/logging/observability.dart` e
> `supabase/migrations/0009_client_logs.sql` eram NÃO COMMITADOS quando este
> plano foi escrito (working tree de 2026-07-16). Se os excerpts não baterem,
> STOP.

## Status

- **Priority**: P2
- **Effort**: S/M
- **Risk**: LOW
- **Depends on**: none
- **Category**: security (data minimization / LGPD)
- **Planned at**: commit `7620a52` (+ working tree), 2026-07-16

## Why this matters

O sink `client_logs` (criado para diagnosticar sync sem Sentry) grava
`error.toString()` cru no Postgres. Mensagens de `PostgrestException` e de
constraint costumam embutir valores de coluna — e-mail, uuid, fragmentos de
payload — ou seja, PII pode ficar materializada em texto claro, para sempre
(a tabela é append-only, sem TTL). O app declara conformidade LGPD (exclusão
de conta com remoção completa). Reduzir o conteúdo na origem + janela de
retenção no banco corta o passivo sem perder o valor diagnóstico (o que
importa é classe do erro + hint de onde ocorreu).

## Current state

- `lib/core/logging/observability.dart` — `_logToSupabase` (~linhas 66–83):

  ```dart
  static Future<void> _logToSupabase(Object error, String? hint) async {
    try {
      final client = SupabaseConfig.clientOrNull;
      final uid = client?.auth.currentUser?.id;
      if (client == null || uid == null) return;
      var msg = error.toString();
      if (msg.length > 2000) msg = '${msg.substring(0, 2000)}...';
      await client.from('client_logs').insert({
        'user_id': uid,
        'nivel': 'error',
        'hint': hint,
        'mensagem': msg,
        'plataforma': defaultTargetPlatform.name,
      });
    } catch (_) {
      // Ignora: nao deixa a gravacao do log quebrar nada.
    }
  }
  ```

- `supabase/migrations/0009_client_logs.sql` — tabela: `id, user_id (FK,
  default auth.uid()), nivel, hint, mensagem text not null, plataforma,
  app_versao, criado_em`. RLS: insert/select próprios; sem update/delete.
  Índice `idx_client_logs_user (user_id, criado_em desc)`.

- Migrations aplicadas são imutáveis — retenção vai em migration NOVA
  (`0012` ou o próximo número livre; **cheque `ls supabase/migrations/`** —
  o plano 011 pode já ter usado 0012).

- Extensão `pg_cron`: NÃO assumida como habilitada. A migration deve criar o
  agendamento só se a extensão existir (guard), senão registrar comentário.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `C:/src/flutter/bin/dart format lib/core/logging/ test/` | exit 0 |
| Analyze | `C:/src/flutter/bin/flutter.bat analyze lib/core/logging/` | No issues |
| Teste novo | `C:/src/flutter/bin/flutter.bat test test/observability_redact_test.dart` | all pass |
| Suíte | `C:/src/flutter/bin/flutter.bat test` | all pass |

## Scope

**In scope**:
- `lib/core/logging/observability.dart`
- `test/observability_redact_test.dart` (create)
- `supabase/migrations/00NN_client_logs_retencao.sql` (create — NN = próximo
  número livre)
- `plans/README.md` (status row)

**Out of scope**:
- Remover o sink client_logs — decisão do dono, fica.
- Policies de RLS do 0009 — corretas, não tocar.
- Sentry/PostHog — inalterados.

## Git workflow

- Branch: `advisor/015-client-logs-minimizacao`
- Commits: `fix(privacidade): redige mensagem de erro antes de gravar em client_logs`
  e `feat(db): retencao de 30 dias em client_logs`
- Não fazer push nem abrir PR sem instrução do operador.

## Steps

### Step 1: Extrair e redigir a mensagem

Em `observability.dart`, extraia uma função top-level (ou static) testável:

```dart
/// Prepara a mensagem de erro para persistir em client_logs: trunca e
/// REDIGE padrões com PII (e-mails, uuids, tokens JWT-like) — mensagens de
/// Postgrest/constraint embutem valores de coluna. Diagnostico precisa da
/// CLASSE do erro + contexto, nao do dado do usuario (LGPD).
@visibleForTesting
String redactErrorMessage(Object error, {int maxLen = 500}) {
  var msg = '${error.runtimeType}: $error';
  msg = msg
      .replaceAll(RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+'), '<email>')
      .replaceAll(
        RegExp(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
            r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'),
        '<uuid>',
      )
      .replaceAll(RegExp(r'eyJ[\w-]+\.[\w-]+\.[\w-]+'), '<jwt>');
  return msg.length > maxLen ? '${msg.substring(0, maxLen)}...' : msg;
}
```

E em `_logToSupabase`, troque o bloco `var msg = ...` por
`final msg = redactErrorMessage(error);`. Note o teto menor (500, não 2000)
— classe+contexto cabem; payloads não deveriam ir.

**Verify**: `flutter analyze lib/core/logging/` → No issues.

### Step 2: Testes da redação

`test/observability_redact_test.dart` (teste puro, padrão
`test/one_rm_test.dart`): e-mail vira `<email>`, uuid vira `<uuid>`, string
`eyJ...`-like vira `<jwt>`, mensagem longa trunca em 500+`...`, mensagem
limpa passa intacta com prefixo do runtimeType.

**Verify**: `flutter test test/observability_redact_test.dart` → all pass.

### Step 3: Migration de retenção

`supabase/migrations/00NN_client_logs_retencao.sql` (próximo número livre):

```sql
-- Retencao de client_logs: 30 dias. Minimiza o passivo de dados
-- (mensagens de erro podem conter fragmentos operacionais mesmo redigidas)
-- e limita crescimento. Sem pg_cron, a limpeza fica documentada para rodar
-- manual/por scheduler externo.
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'client_logs_retencao',
      '17 3 * * *',
      $job$delete from public.client_logs
        where criado_em < now() - interval '30 days'$job$
    );
  else
    raise notice 'pg_cron ausente: agendar limpeza de client_logs externamente';
  end if;
end $$;
```

Cabeçalho `-- ====` no padrão das migrations vizinhas.

**Verify**: arquivo criado; sintaxe conferida por leitura (sem Postgres local
para validar — o harness RLS de `supabase/tests/` pode validar sintaxe se
Docker disponível: rode-o e confirme que nada quebrou).

### Step 4: Registro de aplicação manual

Como 0009–0011: a migration precisa ser colada no SQL Editor pelo operador.
Registre a pendência no relatório final.

**Verify**: n/a.

## Test plan

Step 2 (5 casos de redação). Suíte completa verde ao final.

## Done criteria

- [ ] `grep -n "redactErrorMessage" lib/core/logging/observability.dart` →
      função existe e é usada em `_logToSupabase`
- [ ] `grep -n "substring(0, 2000)" lib/core/logging/observability.dart` →
      sem matches (teto antigo removido)
- [ ] Migration de retenção criada com guard de pg_cron
- [ ] `flutter analyze` 0 issues; `flutter test` all pass (com o teste novo)
- [ ] Nenhum arquivo fora do escopo modificado (`git status`)
- [ ] `plans/README.md` status row atualizada

## STOP conditions

- `_logToSupabase` não existir mais / ter sido refatorado (drift).
- O número de migration escolhido colidir com outro plano executado em
  paralelo (ls antes; se 0012 e 0013 existirem, use 0014, e assim por diante).
- Alguma tela do app exibir `client_logs.mensagem` de volta ao usuário
  (não deveria — se encontrar, reporte antes de mudar o formato).

## Maintenance notes

- A janela de 30 dias é chute conservador — o dono pode ajustar no cron job.
- Exclusão de conta: a FK `user_id ... on delete cascade` do 0009 já apaga os
  logs do usuário — conformidade mantida; revisor deve reconferir isso.
- Se o sink crescer (mais níveis, mais campos), considerar mover a redação
  para uma edge function com service role em vez do client.
