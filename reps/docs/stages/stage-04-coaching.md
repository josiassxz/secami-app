# Stage 4 – Treinador & Aluno (pós-MVP / V1.x)

> **Status:** proposta de design. Não faz parte do MVP (Fases 1–3).
> **Pré-requisito:** Fases 1–3 com critérios de aceite ✅.

## ⚠️ Conflito com decisões fechadas do MVP

Esta fase **reabre** intencionalmente duas decisões registradas no
[CLAUDE.md](../../CLAUDE.md) e no doc de origem. Não comece a implementar
sem o aceite explícito de que estas mudam **só para usuários profissionais**:

1. **"Sem login obrigatório → modo convidado é o padrão."**
   Continua valendo para o usuário comum. Mas **professor e aluno vinculado
   precisam de conta** (o vínculo é entre identidades `auth.users`). O modo
   convidado segue sendo o caminho padrão de quem usa sozinho.
2. **"Sem features sociais."**
   Continua: nada de feed, curtidas, comentários. O vínculo professor↔aluno
   é uma relação **profissional 1-para-1 (ou 1-para-N)**, não rede social.
   A régua: se a feature existe para o aluno treinar melhor com supervisão,
   entra; se existe para usuários se exibirem entre si, fica fora.

Os 5 princípios não negociáveis seguem intactos — em especial **"dado é dono"**:
o aluno mantém autonomia total sobre a própria conta; o professor é um
colaborador com permissões limitadas, não o dono.

## Objetivo de saída

Profissionais (personal trainers) e academias conseguem:
- vincular alunos por **código de convite**;
- **atribuir rotinas** a cada aluno;
- **acompanhar a evolução** (histórico de execução, cargas, volume) em modo leitura.

O aluno continua usando o app exatamente como hoje, agora também recebendo
rotinas atribuídas e sabendo que um treinador acompanha.

---

## 1. Papéis e modelo conceitual

Decisão de produto: **hierarquia "org opcional"**.

- O vínculo canônico é **direto**: `professor (user) → aluno (user)`.
- A **academia** é uma camada **opcional** por cima: um professor pode
  pertencer a uma organização, mas existe e funciona sem ela.
- Um mesmo `auth.users` pode acumular papéis (ser professor de uns e aluno
  de outro). Papel não é uma coluna global rígida — é derivado dos vínculos.

```
academia (organizacao)            ← opcional
   ├── professor A (user) ─┐
   │                       ├─ vínculo ─→ aluno 1 (user)
   │                       └─ vínculo ─→ aluno 2 (user)
   └── professor B (user) ─── vínculo ─→ aluno 3 (user)

professor autônomo (user) ─ vínculo ─→ aluno 4 (user)   (sem organização)
```

Permissões do professor sobre o aluno (decisão fechada):
- **Pode:** criar/editar rotinas **que ele atribuiu**; ler o histórico de
  execução (sessões, séries, cargas, cardio); ler rotinas próprias do aluno.
- **Não pode:** editar/apagar o que o aluno registrou; mexer em rotinas que
  o próprio aluno criou; alterar preferências/conta do aluno.

---

## 2. Modelo de dados

Espelha o estilo de [03-data-model.md](../03-data-model.md): `snake_case`,
pt-BR, campos comuns de sync (`updated_at`, `deleted_at`, `device_id`) **só**
onde a entidade for sincronizada no aparelho do dono. Tabelas do módulo coach
(`organizacoes`, `vinculos`, `convites`, membros) são **server-side**, não
entram no Drift local nem no `SyncEngine` (ver §5).

### Novos enums

| Enum | Valores |
|---|---|
| `status_vinculo` | `pendente`, `ativo`, `recusado`, `encerrado` |
| `papel_org` | `dono`, `admin`, `professor` |
| `tipo_convite` | `professor_aluno`, `org_professor` |
| `origem_rotina` | `propria`, `atribuida` |

### `organizacoes` (academia) — opcional

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `nome` | text | nome da academia |
| `dono_user_id` | uuid FK users | criador/dono |
| `criado_em` | timestamptz | |
| `updated_at` / `deleted_at` | timestamptz | server-side |

### `organizacao_membros`

Quem trabalha na academia (professores e administradores).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `org_id` | uuid FK organizacoes | |
| `user_id` | uuid FK users | |
| `papel` | `papel_org` | dono / admin / professor |
| `status` | `status_vinculo` | pendente até aceitar convite |
| único | `(org_id, user_id)` | |

### `vinculos` (professor ↔ aluno) — núcleo

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `professor_id` | uuid FK users | quem acompanha |
| `aluno_id` | uuid FK users | quem é acompanhado |
| `org_id` | uuid FK organizacoes | **nullable** (professor autônomo) |
| `status` | `status_vinculo` | |
| `criado_em` | timestamptz | |
| `aceito_em` | timestamptz | quando o aluno aceitou |
| `encerrado_em` | timestamptz | |
| único | `(professor_id, aluno_id)` | onde `deleted_at is null` |

### `convites`

Código curto que o aluno (ou professor) digita para se vincular.

| Campo | Tipo | Notas |
|---|---|---|
| `id` | uuid PK | |
| `codigo` | text único | curto, ex. `R3PS-7QX2` (gerado server-side) |
| `tipo` | `tipo_convite` | aluno→professor ou professor→academia |
| `criado_por` | uuid FK users | professor (ou dono da org) |
| `org_id` | uuid FK organizacoes | nullable |
| `expira_em` | timestamptz | default +7 dias |
| `usos_max` | int | default 1; turma pode usar N |
| `usos` | int | default 0 |
| `status` | text | `ativo` / `expirado` / `revogado` |

### Mudanças em `routines`

A rotina atribuída **vive na conta do aluno** (`user_id = aluno`), para que
sincronize no aparelho dele sem nenhuma mudança no fluxo do aluno. Distinguimos
por duas colunas novas:

| Campo novo | Tipo | Notas |
|---|---|---|
| `origem` | `origem_rotina` | default `propria`; `atribuida` quando criada pelo professor |
| `atribuido_por` | uuid FK users | nullable; o professor que atribuiu |

Nenhuma outra tabela muda de forma. Sessões/séries do aluno permanecem como
estão — o professor as **lê** via RLS, não as duplica.

---

## 3. Migração SQL proposta (`supabase/migrations/0002_coaching.sql`)

> Esboço para revisão — **não aplicar** sem aprovar o design.

```sql
-- Enums
do $$ begin create type status_vinculo as enum
  ('pendente','ativo','recusado','encerrado');
exception when duplicate_object then null; end $$;

do $$ begin create type papel_org as enum ('dono','admin','professor');
exception when duplicate_object then null; end $$;

do $$ begin create type tipo_convite as enum
  ('professor_aluno','org_professor');
exception when duplicate_object then null; end $$;

do $$ begin create type origem_rotina as enum ('propria','atribuida');
exception when duplicate_object then null; end $$;

-- organizacoes
create table if not exists public.organizacoes (
  id uuid primary key default uuid_generate_v4(),
  nome text not null,
  dono_user_id uuid not null references public.users(id) on delete cascade,
  criado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create trigger trg_organizacoes_updated_at before update on public.organizacoes
  for each row execute function public.set_updated_at();

-- organizacao_membros
create table if not exists public.organizacao_membros (
  id uuid primary key default uuid_generate_v4(),
  org_id uuid not null references public.organizacoes(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  papel papel_org not null default 'professor',
  status status_vinculo not null default 'pendente',
  criado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (org_id, user_id)
);
create trigger trg_org_membros_updated_at before update
  on public.organizacao_membros
  for each row execute function public.set_updated_at();

-- vinculos (professor <-> aluno)
create table if not exists public.vinculos (
  id uuid primary key default uuid_generate_v4(),
  professor_id uuid not null references public.users(id) on delete cascade,
  aluno_id uuid not null references public.users(id) on delete cascade,
  org_id uuid references public.organizacoes(id) on delete set null,
  status status_vinculo not null default 'pendente',
  criado_em timestamptz not null default now(),
  aceito_em timestamptz,
  encerrado_em timestamptz,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  check (professor_id <> aluno_id)
);
create unique index if not exists uq_vinculo_ativo
  on public.vinculos (professor_id, aluno_id)
  where deleted_at is null;
create index if not exists idx_vinculos_professor on public.vinculos (professor_id);
create index if not exists idx_vinculos_aluno on public.vinculos (aluno_id);
create trigger trg_vinculos_updated_at before update on public.vinculos
  for each row execute function public.set_updated_at();

-- convites
create table if not exists public.convites (
  id uuid primary key default uuid_generate_v4(),
  codigo text unique not null,
  tipo tipo_convite not null default 'professor_aluno',
  criado_por uuid not null references public.users(id) on delete cascade,
  org_id uuid references public.organizacoes(id) on delete cascade,
  expira_em timestamptz not null default (now() + interval '7 days'),
  usos_max int not null default 1,
  usos int not null default 0,
  status text not null default 'ativo',
  criado_em timestamptz not null default now()
);
create index if not exists idx_convites_codigo on public.convites (codigo);

-- routines: marca rotina atribuida
alter table public.routines
  add column if not exists origem origem_rotina not null default 'propria',
  add column if not exists atribuido_por uuid references public.users(id);

-- =========================================================
-- Helper: o auth.uid() atual eh treinador ATIVO do aluno?
-- security definer p/ ler vinculos sem recursao de RLS.
-- =========================================================
create or replace function public.eh_treinador_de(p_aluno uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.vinculos v
    where v.professor_id = auth.uid()
      and v.aluno_id = p_aluno
      and v.status = 'ativo'
      and v.deleted_at is null
  );
$$;

-- =========================================================
-- RLS das novas tabelas
-- =========================================================
alter table public.organizacoes        enable row level security;
alter table public.organizacao_membros enable row level security;
alter table public.vinculos            enable row level security;
alter table public.convites            enable row level security;

-- vinculos: professor ve os seus, aluno ve os seus
create policy vinculos_select on public.vinculos for select
  using (professor_id = auth.uid() or aluno_id = auth.uid());
-- professor cria vinculo (via convite, ver RPC); aluno aceita/recusa
create policy vinculos_prof_insert on public.vinculos for insert
  with check (professor_id = auth.uid());
create policy vinculos_update on public.vinculos for update
  using (professor_id = auth.uid() or aluno_id = auth.uid());

-- organizacoes: dono e membros leem; dono escreve
create policy org_select on public.organizacoes for select
  using (
    dono_user_id = auth.uid()
    or exists (select 1 from public.organizacao_membros m
               where m.org_id = id and m.user_id = auth.uid()
                 and m.status = 'ativo')
  );
create policy org_owner_all on public.organizacoes for all
  using (dono_user_id = auth.uid()) with check (dono_user_id = auth.uid());

create policy org_membros_select on public.organizacao_membros for select
  using (user_id = auth.uid()
    or exists (select 1 from public.organizacoes o
               where o.id = org_id and o.dono_user_id = auth.uid()));

-- convites: criador gerencia; leitura por codigo via RPC (abaixo)
create policy convites_owner on public.convites for all
  using (criado_por = auth.uid()) with check (criado_por = auth.uid());

-- =========================================================
-- Amplia RLS das tabelas do aluno p/ leitura do treinador.
-- (substituem as policies "owner" de 0001 nas tabelas de leitura)
-- =========================================================

-- routines: dono OU treinador ativo (leitura); treinador escreve atribuidas
drop policy if exists routines_owner on public.routines;
create policy routines_select on public.routines for select
  using (user_id = auth.uid() or public.eh_treinador_de(user_id));
create policy routines_insert on public.routines for insert
  with check (user_id = auth.uid() or public.eh_treinador_de(user_id));
create policy routines_update on public.routines for update
  using (
    user_id = auth.uid()
    or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid())
  )
  with check (
    user_id = auth.uid()
    or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid())
  );
create policy routines_delete on public.routines for delete
  using (user_id = auth.uid()
    or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid()));

-- routine_exercises: via dono da routine OU treinador
drop policy if exists routine_exercises_owner on public.routine_exercises;
create policy routine_exercises_rw on public.routine_exercises for all
  using (exists (select 1 from public.routines r where r.id = routine_id
           and (r.user_id = auth.uid() or public.eh_treinador_de(r.user_id))))
  with check (exists (select 1 from public.routines r where r.id = routine_id
           and (r.user_id = auth.uid()
                or (public.eh_treinador_de(r.user_id)
                    and r.atribuido_por = auth.uid()))));

-- workout_sessions: dono escreve; treinador SO LE
drop policy if exists sessions_owner on public.workout_sessions;
create policy sessions_owner_rw on public.workout_sessions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy sessions_coach_read on public.workout_sessions for select
  using (public.eh_treinador_de(user_id));

-- set_logs: dono escreve; treinador SO LE (via session)
drop policy if exists set_logs_owner on public.set_logs;
create policy set_logs_owner_rw on public.set_logs for all
  using (exists (select 1 from public.workout_sessions s
           where s.id = session_id and s.user_id = auth.uid()))
  with check (exists (select 1 from public.workout_sessions s
           where s.id = session_id and s.user_id = auth.uid()));
create policy set_logs_coach_read on public.set_logs for select
  using (exists (select 1 from public.workout_sessions s
           where s.id = session_id and public.eh_treinador_de(s.user_id)));

-- cardio_sessions: dono escreve; treinador SO LE
drop policy if exists cardio_owner on public.cardio_sessions;
create policy cardio_owner_rw on public.cardio_sessions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy cardio_coach_read on public.cardio_sessions for select
  using (public.eh_treinador_de(user_id));

-- =========================================================
-- RPC: resgatar convite (aluno digita codigo)
-- =========================================================
create or replace function public.resgatar_convite(p_codigo text)
returns public.vinculos language plpgsql security definer
set search_path = public as $$
declare
  c public.convites;
  v public.vinculos;
begin
  select * into c from public.convites
    where codigo = p_codigo and status = 'ativo'
      and expira_em > now() and usos < usos_max
    for update;
  if not found then
    raise exception 'convite invalido ou expirado';
  end if;

  if c.tipo = 'professor_aluno' then
    insert into public.vinculos (professor_id, aluno_id, org_id, status, aceito_em)
    values (c.criado_por, auth.uid(), c.org_id, 'ativo', now())
    on conflict do nothing
    returning * into v;
  else -- org_professor
    insert into public.organizacao_membros (org_id, user_id, papel, status)
    values (c.org_id, auth.uid(), 'professor', 'ativo')
    on conflict (org_id, user_id) do update set status = 'ativo';
  end if;

  update public.convites set usos = usos + 1,
    status = case when usos + 1 >= usos_max then 'expirado' else 'ativo' end
    where id = c.id;
  return v;
end;
$$;
```

---

## 4. Fluxos

### 4.1 Professor cria vínculo
1. Professor abre **Meus alunos → Convidar** → app chama RPC `criar_convite`.
2. App mostra código + botão "compartilhar" (`share_plus`).
3. Aluno digita o código em **Conta → Tenho um treinador** → RPC
   `resgatar_convite` → vínculo `ativo`.
4. Ambos veem o vínculo na hora (online).

### 4.2 Professor atribui rotina
1. Professor abre o aluno → **Atribuir treino**.
2. Monta a rotina (reusa o `RoutineBuilder`) → grava `routines` com
   `user_id = aluno`, `origem = atribuida`, `atribuido_por = professor`.
3. Sync do **aluno** baixa a rotina como qualquer outra → aparece em Treinos
   com selo "do seu treinador".

### 4.3 Professor acompanha evolução
1. Professor abre o aluno → **Evolução** (tela online-only).
2. App consulta Supabase direto (sessões, séries, volume semanal, PRs).
3. Read-only: nenhuma edição do histórico do aluno.

---

## 5. Impacto no `SyncEngine` (ponto crítico)

Hoje [sync_engine.dart](../../lib/core/sync/sync_engine.dart) faz
`_pullTable` com `select()` da tabela inteira e confia que a **RLS só
devolve linhas do próprio usuário** (`user_id = auth.uid()`).

Ao ampliarmos a RLS para o treinador ler dados dos alunos, esse pull
passaria a **baixar o histórico de todos os alunos para o Drift local do
professor**, misturando com os dados dele. Isso quebra o local-first.

**Regra de design:** dados de aluno **nunca** entram no banco local do
professor. Mudanças necessárias:

1. **Filtro explícito de dono no pull.** Em `_pullTable`, para as tabelas
   por-usuário, filtrar `user_id = eq.<auth.uid()>` (e `set_logs` /
   `routine_exercises` via `session_id`/`routine_id` do próprio usuário, ou
   adicionar coluna `owner_user_id` denormalizada nessas filhas para filtrar
   direto). O sync continua estritamente "só meus dados".
   - Exceção desejada: rotina **atribuída** tem `user_id = aluno`, mas é do
     aluno — então no aparelho do **aluno** baixa normal; no aparelho do
     **professor** ela só aparece na visão online de coach, não no Drift.
2. **Camada coach online-only.** Novo `CoachRepository` que lê Supabase
   direto (sem Drift, sem `dirty`/last-write-wins), com cache em memória e
   pull-to-refresh. Telas de coach (lista de alunos, evolução) consomem isso.
3. **Escrita de rotina atribuída** continua via REST do Supabase (professor
   escreve direto na tabela `routines` do aluno); não passa pela fila `dirty`
   local do professor.

Sem o item 1, o vazamento de dados entre contas é certo. É o primeiro a fazer.

---

## 6. Telas (Flutter, feature-first)

`lib/features/coaching/` com `data/`, `domain/`, `presentation/`.

| Tela | Papel | Conteúdo |
|---|---|---|
| `MeusAlunosScreen` | professor | lista de alunos (status, último treino), botão Convidar |
| `ConviteSheet` | professor | código gerado + compartilhar |
| `AlunoDetalheScreen` | professor | abas: Evolução / Treinos atribuídos / Perfil |
| `AlunoEvolucaoScreen` | professor | volume semanal, PRs, frequência (reusa widgets de insights, read-only) |
| `AtribuirTreinoScreen` | professor | reusa `RoutineBuilder`, grava na conta do aluno |
| `MeuTreinadorScreen` | aluno | quem acompanha; campo "tenho um treinador" (resgatar código); botão encerrar vínculo |
| `OrgAdminScreen` | dono/admin | gerenciar professores da academia (opcional, fase final) |

Navegação: entrada em **Conta/Settings** ("Sou profissional" / "Tenho um
treinador"), não na bottom nav principal (que segue ≤5 itens). Rotina atribuída
recebe selo na `RoutinesScreen` e é read-only para o aluno (ele pode desativar,
não editar) — ver decisão em aberto D3.

---

## 7. Fases de entrega

- **E4.1 – Fundação de identidade & sync seguro** ✅
  - [x] Migração `0002_coaching.sql` (tabelas, enums, RLS, `eh_treinador_de`,
    `criar_convite`, `resgatar_convite`, `owner_user_id` + triggers nas filhas).
  - [x] **Filtro de dono explícito no `SyncEngine._pullTable`** (§5.1):
    todo pull filtra `<owner>=eq.<uid>`.
  - [x] Teste anti-regressão `test/sync_owner_filter_test.dart` (5 tabelas).
- **E4.2 – Vínculo por convite** ✅
  - [x] `CoachRepository` online (vínculos/convites); `MeuTreinadorScreen`
    (resgata código, encerra); `MeusAlunosScreen` + `ConviteSheet`.
- **E4.3 – Atribuição de treino** ✅
  - [x] `routines.origem` + `atribuido_por` (Drift schemaV3 + sync mapping);
    `CoachRepository.atribuirRotina` clona rotina própria → conta do aluno;
    `AtribuirTreinoScreen`; selo "Do seu treinador" na `RoutinesScreen`.
- **E4.4 – Acompanhamento de evolução** ✅
  - [x] `CoachRepository.evolucaoAluno` (online, via `owner_user_id` + RLS);
    aba **Evolução** em `AlunoDetalheScreen` (sessões 30d, séries, volume por
    grupo, últimas sessões). PRs ficam para iteração futura.
- **E4.5 – Academia (org)** ✅
  - [x] `criarOrg`/`minhasOrgs`/`membrosDaOrg`; convite `org_professor`;
    `OrgAdminScreen`. Migração `0004` (RLS de users por org).
- **E4.6 – Polimento** ⏳ parcial
  - [x] Consentimento LGPD explícito ao resgatar convite (D2).
  - [x] Encerrar vínculo (ambos os lados); estados vazios/erro padronizados.
  - [ ] Notificações (treino atribuído / aluno treinou) — **adiado**: exige
    push/trigger server-side que ainda não existe no projeto.

### ⚠️ Migrações a aplicar no Supabase (SQL Editor, nesta ordem)
`0002_coaching.sql` → `0003_coaching_users_rls.sql` → `0004_org_users_rls.sql`.
(0002 já foi aplicada; aplicar 0003 e 0004.)

---

## 8. Critérios de aceite (gate)

- [ ] `flutter analyze` 0 issues; testes novos passando.
- [ ] **Isolamento de sync:** teste integrado prova que, com vínculo ativo,
      o Drift local do professor **não** contém `workout_sessions`/`set_logs`
      de aluno. (Anti-regressão do §5.)
- [ ] RLS: aluno **não** lê dados de outro aluno do mesmo professor.
- [ ] RLS: professor sem vínculo ativo **não** lê nada do (ex-)aluno.
- [ ] Professor edita só rotinas com `atribuido_por = ele`; nunca o que o
      aluno criou nem o histórico registrado.
- [ ] Aluno consegue **encerrar o vínculo** e o acesso do professor cai na hora.
- [ ] Fluxo de convite funciona com código expirado/ inválido (erro claro).
- [ ] Consentimento LGPD registrado antes do primeiro compartilhamento.

---

## 9. Decisões em aberto

- **D1 – Monetização.** Coaching é o plano `pro` (já existe enum
  `plano_usuario`)? Cobra do professor por aluno, ou da academia? Não bloqueia
  E4.1–E4.4, mas define gating de UI.
- **D2 – Consentimento/LGPD.** ✅ **Resolvido:** diálogo de consentimento
  explícito no `MeuTreinadorScreen` antes de resgatar o convite (o aluno
  autoriza compartilhar treinos/séries/cargas/evolução). Falta registrar o
  aceite em tabela de auditoria, se exigido juridicamente.
- **D3 – Aluno edita rotina atribuída?** Proposta: não edita (só desativa);
  se editar, vira `origem = propria` (fork) e o professor perde a referência.
- **D4 – Owner denormalizado nas tabelas filhas.** ✅ **Resolvido:**
  `owner_user_id` adicionado em `set_logs`/`routine_exercises` (server-side,
  preenchido por trigger a partir do parent). O cliente nem conhece a coluna —
  só filtra o pull por ela. Simples no cliente; backfill + trigger no servidor.
- **D5 – Sub-navegação da academia** quando um professor pertence a várias orgs.
```
