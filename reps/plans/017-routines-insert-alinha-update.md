# Plan 017: Alinhar `routines_insert` (RLS) com update/delete — treinador só insere rotina atribuída

## Status
- **Priority**: P2 / **Effort**: S / **Risk**: LOW / **Depends on**: none / **Category**: security
- **Planned at**: commit `cadf58b`, 2026-07-17

## Why this matters
A policy `routines_insert` (0002) permite ao treinador inserir na conta do aluno
com `with check (user_id = auth.uid() or eh_treinador_de(user_id))` — sem exigir
`atribuido_por = auth.uid()` nem `origem = 'atribuida'`. Já `routines_update` e
`routines_delete` exigem os dois. Consequência: um treinador ativo pode inserir
rotina na conta do aluno marcada como `origem='propria'`/`atribuido_por=null`,
indistinguível de uma do próprio aluno — e que a própria policy de update/delete
do treinador depois NÃO cobre (ele não consegue removê-la). Assimetria de RLS que
quebra a integridade da atribuição dentro do relacionamento de coaching.

## Current state
- `supabase/migrations/0002_coaching.sql` (linhas 232–248) — as três policies:
  ```sql
  create policy routines_insert on public.routines for insert
    with check (user_id = auth.uid() or public.eh_treinador_de(user_id));
  create policy routines_update on public.routines for update
    using (user_id = auth.uid() or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid()))
    with check (user_id = auth.uid() or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid()));
  create policy routines_delete on public.routines for delete
    using (user_id = auth.uid() or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid()));
  ```
- `lib/features/coaching/data/coach_repository.dart` (~linhas 187–196) — o cliente
  legítimo SEMPRE seta `origem: 'atribuida'` e `atribuido_por: uid` ao inserir
  rotina de treinador; então apertar o `with check` não quebra o fluxo real.
- Coluna `origem` é enum `origem_rotina` com default `'propria'` (0002); valor de
  treinador é `'atribuida'`.
- Migrations aplicadas são imutáveis — o fix vai em migration NOVA (`0014`;
  confirme com `ls supabase/migrations/` que 0013 é o maior).
- Convenção: cabeçalho `-- ====`, snake_case pt-BR. Exemplar: `0012_criar_convite_exige_dono_org.sql`.

## Commands
| Purpose | Command | Expected |
|---|---|---|
| Analyze (não deve mudar) | `C:/src/flutter/bin/flutter.bat analyze` | 1 info anonKey pré-existente, 0 erros |
| RLS harness (precisa Docker) | `bash supabase/tests/run_rls_tests.sh` | exit 0 (provavelmente indisponível — registrar) |

## Scope
IN: `supabase/migrations/0014_routines_insert_atribuida.sql` (create).
OUT: `0002_coaching.sql` e demais migrations (imutáveis), `lib/**`, harness (Docker
indisponível; o teste RLS deste guard fica junto do follow-up "estender harness"),
`.claude/settings.json`, `plans/`.

## Git
Branch `advisor/017-routines-insert-alinha`. Commit `fix(rls): routines_insert exige atribuido_por/origem do treinador`. Sem push.

## Steps
### Step 1: migration 0014
Criar `supabase/migrations/0014_routines_insert_atribuida.sql` que recria SÓ a
policy `routines_insert` (drop if exists + create), alinhando o ramo de treinador
ao de update/delete:
```sql
drop policy if exists routines_insert on public.routines;
create policy routines_insert on public.routines for insert
  with check (
    user_id = auth.uid()
    or (
      public.eh_treinador_de(user_id)
      and atribuido_por = auth.uid()
      and origem = 'atribuida'
    )
  );
```
Cabeçalho `-- ====` explicando a assimetria e o fix, citando 0002.
**Verify**: arquivo criado; `git status` mostra só ele novo no escopo.

### Step 2: aplicação manual
NÃO aplique no Supabase. Registre no relatório que a aplicação manual fica pendente
do operador.

## Done criteria
- [ ] `supabase/migrations/0014_routines_insert_atribuida.sql` existe e recria
      `routines_insert` com `atribuido_por = auth.uid() and origem = 'atribuida'`
      no ramo de treinador
- [ ] `flutter analyze` inalterado (1 info anonKey)
- [ ] Nenhum arquivo fora do escopo modificado
- [ ] Commit na branch advisor/017-*

## STOP conditions
- A policy `routines_insert` vigente divergir do excerpt (mexeram após 0002).
- Descobrir fluxo legítimo em que o treinador insere rotina SEM `atribuido_por`
  (ex.: algum caminho no app que não seta os campos) — pare e reporte; apertar o
  check quebraria esse caminho.

## Maintenance notes
- O teste RLS deste guard depende de estender o harness (`run_rls_tests.sh` só
  aplica 0001..0008 e não semeia coaching além do mínimo) — follow-up já no índice.
- Revisor: conferir que o `origem = 'atribuida'` bate com o enum e com o que o
  `coach_repository.atribuirRotina` grava.
