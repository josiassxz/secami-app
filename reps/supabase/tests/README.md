# Testes de RLS (isolamento professor ↔ aluno)

Harness que aplica as migrations num **Postgres efêmero em container** e verifica
que as políticas de Row-Level Security isolam os dados entre tenants. É a rede de
segurança que faltava: nenhum teste Dart exercita RLS (o app usa Drift/SQLite em
memória, que não tem `auth.uid()`), então uma policy mal configurada passava sem
ninguém notar (`test/coach_repository_test.dart` documenta essa lacuna).

## Como rodar

```bash
bash supabase/tests/run_rls_tests.sh
```

Requer **apenas Docker**. Sai com código ≠ 0 se qualquer caso falhar. Roda igual
local (Git Bash/WSL/macOS/Linux) e no CI (`.github/workflows/rls.yml`).

## O que tem aqui

| Arquivo | Papel |
|---|---|
| `01_auth_shim.sql` | Recria o mínimo do ambiente Supabase num PG puro: schema `auth` (`auth.users` + `auth.uid()` lendo o GUC `request.jwt.claims`) e os roles `anon`/`authenticated`/`service_role`. Roda **antes** das migrations (0005 referencia `authenticated`). |
| `02_grants.sql` | `GRANT` de tabela para `authenticated` (camada separada da RLS). Roda **depois** das migrations. |
| `03_seed.sql` | Cenário: P1/P2 (profs), A1 (aluno de P1), A2 (aluno de P2), vínculos ativos, 1 sessão + 1 set_log por aluno. Roda como superuser (ignora RLS). |
| `10_rls_cases.sql` | Os casos. Cada um seta o "usuário logado" (claims + `set role authenticated`) e levanta exception se a expectativa quebrar. |
| `run_rls_tests.sh` | Orquestra container + aplicação + casos. |

## Casos cobertos

1. Treinador lê a sessão do seu aluno (e só dele) — `sessions_coach_read`.
2. Aluno não lê a sessão de outro aluno.
3. Treinador não lê `set_logs` de quem não é seu aluno.
4. Professor não enxerga o vínculo de outro professor — `vinculos_select`.
5. Professor não consegue reatribuir `professor_id` (sequestrar vínculo).
6. Controle positivo: professor encerra o próprio vínculo (a policy não nega tudo).
7. Treinador lê o registro `users` (nome/email) do aluno; não-relacionado não lê — `users_select_rel` (0003).

## Como simulamos `auth.uid()`

O Supabase deriva `auth.uid()` do claim `sub` do JWT. Aqui `auth.uid()` lê o GUC
de sessão `request.jwt.claims` (mesmo nome do PostgREST). Cada caso faz, dentro de
uma transação:

```sql
select set_config('request.jwt.claims', '{"sub":"<uuid>"}', true);
set local role authenticated;     -- RLS é aplicada (não é dono nem superuser)
```

As funções `security definer` (`eh_treinador_de`, etc.) rodam como o dono mas leem
`auth.uid()` do GUC de sessão — exatamente como no Supabase.

## Achado registrado: o `WITH CHECK` do 0008 é redundante

O controle negativo deste harness mostrou algo que corrige a premissa do achado
**SEC-01 / plano 002**: o CASE 5 passa **com ou sem** a migration
`0008_vinculos_with_check.sql`.

Motivo: numa policy de **UPDATE sem `WITH CHECK`, o Postgres aplica a expressão
`USING` também à linha NOVA**. A `USING` de `vinculos_update` (migration 0002) já
negava reatribuir `professor_id`. O `WITH CHECK` do 0008 usa o **mesmo predicado**,
então é funcionalmente **redundante** — deixa a regra explícita, mas não fechava
nenhum buraco real. O 0008 é higiene defensiva inofensiva, não um fix de
segurança. Mantê-lo é ok (explícito > implícito), mas a severidade original do
achado estava superestimada.

A sensibilidade do harness foi confirmada por outro controle negativo: remover
`sessions_coach_read` faz o CASE 1 falhar — ou seja, os casos pegam regressão de
verdade.

## Limitações

- Shape "PG puro + shim", não o stack Supabase completo (sem GoTrue/PostgREST).
  Cobre RLS/policies/funções; **não** cobre fluxo de Auth nem Edge Functions.
- O shim de `auth.users` tem só as colunas que os triggers usam.
