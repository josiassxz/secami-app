# Plan 011: Exigir posse da organização em `criar_convite` (fecha escalonamento entre tenants)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 7620a52..HEAD -- supabase/migrations/ supabase/tests/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `7620a52`, 2026-07-16

## Why this matters

A função `criar_convite` é `SECURITY DEFINER` e aceita um `p_org` arbitrário
sem verificar que quem chama é dono (ou admin) daquela organização. Qualquer
usuário autenticado pode emitir um convite `org_professor` apontando para o
`org_id` de uma academia de terceiros; quem resgatar o código vira membro
`professor` **ativo** dessa org (via `resgatar_convite`), ganhando a
visibilidade que `eh_membro_org_ativo` concede. É um furo de isolamento de
tenant no módulo de coaching e um gate para qualquer beta desse módulo.

## Current state

- `supabase/migrations/0002_coaching.sql` — definição original de
  `criar_convite` (seção 10, linhas 295–328) e `resgatar_convite` (seção 11).
  No ramo `org_professor` de `resgatar_convite` (linhas ~357–361):

  ```sql
  else -- org_professor
    insert into public.organizacao_membros (org_id, user_id, papel, status)
    values (c.org_id, auth.uid(), 'professor', 'ativo')
    on conflict (org_id, user_id) do update set status = 'ativo';
  ```

- `supabase/migrations/0011_criar_convite_search_path.sql` — redefinição mais
  recente de `criar_convite` (fix de `search_path`). É esta a versão vigente.
  Trecho relevante (linhas 16–23 e 41–47):

  ```sql
  create or replace function public.criar_convite(
    p_tipo tipo_convite default 'professor_aluno',
    p_org uuid default null,
    p_usos_max int default 1,
    p_validade_dias int default 7
  )
  returns public.convites language plpgsql security definer
  set search_path = public, extensions as $$
  ...
    insert into public.convites
      (codigo, tipo, criado_por, org_id, usos_max, expira_em)
    values
      (v_codigo, p_tipo, auth.uid(), p_org, greatest(p_usos_max, 1),
       now() + make_interval(days => greatest(p_validade_dias, 1)))
  ```

  Nenhuma checagem de posse de `p_org` em nenhuma das duas versões.

- `supabase/migrations/0010_fix_org_rls_recursion.sql` — define o helper
  `public.eh_dono_org(p_org uuid) returns boolean` (SECURITY DEFINER, checa
  `organizacoes.dono_user_id = auth.uid()`). **Use este helper** no guard.

- `supabase/tests/` — harness de testes RLS que roda um Postgres efêmero via
  Docker (`run_rls_tests.sh`, casos em SQL). Não cobre convites hoje.

- Convenção de migrations: arquivos `NNNN_slug.sql` numerados, cabeçalho em
  comentário `-- ====` explicando o porquê (veja `0010_fix_org_rls_recursion.sql`
  como exemplar). Colunas/tabelas em `snake_case` pt-BR.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Testes RLS (precisa Docker) | `bash supabase/tests/run_rls_tests.sh` | exit 0, todos os casos verdes |
| Análise estática Dart (não deve mudar) | `C:/src/flutter/bin/flutter.bat analyze` | 0 erros |

Se Docker não estiver disponível, o teste RLS não roda localmente — verifique
a sintaxe SQL de outra forma (leitura cuidadosa) e registre no relatório que a
verificação executável ficou pendente do CI (`.github/workflows/rls.yml`).

## Scope

**In scope** (only files you may create/modify):
- `supabase/migrations/0012_criar_convite_exige_dono_org.sql` (create)
- `supabase/tests/` — adicionar caso de teste (siga o padrão dos casos
  existentes no diretório)
- `plans/README.md` (status row)

**Out of scope** (do NOT touch):
- `supabase/migrations/0002_coaching.sql` e `0011_criar_convite_search_path.sql`
  — migrations já aplicadas são imutáveis; o fix vai numa migration NOVA.
- `lib/features/coaching/**` — nenhuma mudança de app é necessária; o fluxo
  legítimo (dono criando convite da própria org) continua idêntico.
- `resgatar_convite` — não mexer; o guard na emissão fecha o vetor.

## Git workflow

- Branch: `advisor/011-criar-convite-guard-org`
- Commit style (conventional, pt-BR — exemplo do repo:
  `fix: recursao de RLS entre organizacoes e organizacao_membros`):
  `fix(rls): criar_convite exige dono da org em convites org_professor`
- Não fazer push nem abrir PR sem instrução do operador.

## Steps

### Step 1: Escrever a migration 0012

Criar `supabase/migrations/0012_criar_convite_exige_dono_org.sql` que
redefine `public.criar_convite` **idêntica à versão do 0011** (copie o corpo
de lá — inclusive `set search_path = public, extensions`), adicionando no
início do corpo (antes do loop de geração de código):

```sql
  -- Convite atrelado a organizacao exige que o emissor seja o dono dela.
  -- Sem este guard, qualquer autenticado emitia convite org_professor para
  -- org alheia e o resgate inseria membro ativo (furo de tenant).
  if p_org is not null and not public.eh_dono_org(p_org) then
    raise exception 'apenas o dono da organizacao pode criar convites dela';
  end if;
  if p_tipo = 'org_professor' and p_org is null then
    raise exception 'convite org_professor exige organizacao';
  end if;
```

Cabeçalho da migration no padrão do repo (comentário `-- ====` explicando o
furo e o fix, citando 0002/0011).

**Verify**: arquivo existe e `git diff --stat` mostra só ele novo.

### Step 2: Adicionar caso no harness RLS

No diretório `supabase/tests/`, seguindo o padrão dos casos existentes
(leia primeiro 1–2 casos para copiar a estrutura de setup/assert):

- Caso positivo: usuário A dono da org X cria convite `org_professor` com
  `p_org = X` → sucesso.
- Caso negativo: usuário B (não dono de X) chama `criar_convite('org_professor', X, ...)`
  → deve falhar com exceção.
- Caso negativo 2: `criar_convite('org_professor', null, ...)` → deve falhar.

**Verify**: `bash supabase/tests/run_rls_tests.sh` → exit 0, casos novos
aparecem e passam (com Docker; senão, registrar pendência de CI).

### Step 3: Aplicar no Supabase (manual do operador)

A migration precisa ser aplicada no projeto Supabase (SQL Editor ou
`supabase db push`). **Não tente aplicar você mesmo** — registre no relatório
final que a aplicação manual está pendente, igual foi feito com 0009–0011.

**Verify**: n/a (ação do operador).

## Test plan

- Casos do harness RLS do Step 2 (positivo + 2 negativos).
- Nenhum teste Dart novo (não há mudança de app).
- Verificação: `bash supabase/tests/run_rls_tests.sh` → todos verdes.

## Done criteria

- [ ] `supabase/migrations/0012_criar_convite_exige_dono_org.sql` existe e
      contém `eh_dono_org` no corpo de `criar_convite`
- [ ] Harness RLS tem caso cobrindo emissão de convite org por não-dono
- [ ] `bash supabase/tests/run_rls_tests.sh` exit 0 (ou pendência de Docker
      registrada explicitamente)
- [ ] Nenhum arquivo fora do escopo modificado (`git status`)
- [ ] `plans/README.md` status row atualizada

## STOP conditions

- O corpo vigente de `criar_convite` divergir do excerpt (alguém já mexeu
  depois do 0011) — reconciliar antes.
- O harness `supabase/tests/` tiver estrutura incompatível com adicionar um
  caso de convites (ex.: sem seed de orgs) e a adaptação exigir refatorar o
  harness — reporte em vez de refatorar.
- Descobrir que existe fluxo legítimo em que um **membro admin** (não dono)
  precisa emitir convite — o guard atual só aceita dono; pare e pergunte se
  deve aceitar admin também.

## Maintenance notes

- Se um papel `admin` de org ganhar permissão de emitir convites no futuro, o
  guard deve virar `eh_dono_org(p_org) or eh_admin_org(p_org)`.
- Revisor: conferir que a migration redefine a função INTEIRA (não `alter`),
  e que o `search_path` do 0011 foi preservado (regressão fácil).
- Follow-up deferido: SEC-04 (policy de INSERT de `routines` mais frouxa que
  update/delete) — plano futuro; mesmo arquivo 0002 de origem.
