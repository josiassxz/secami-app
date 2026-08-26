-- =============================================================
-- reps - Stage 4: Treinador & Aluno (pos-MVP)
-- Vinculo professor<->aluno por convite, atribuicao de treino,
-- leitura de evolucao pelo treinador. Academia (org) opcional.
--
-- Design: docs/stages/stage-04-coaching.md
-- Idempotente o quanto possivel. Cole no SQL Editor do Supabase.
-- =============================================================

-- ============================================================
-- 1. Enums
-- ============================================================
do $$ begin
  create type status_vinculo as enum
    ('pendente','ativo','recusado','encerrado');
exception when duplicate_object then null; end $$;

do $$ begin
  create type papel_org as enum ('dono','admin','professor');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_convite as enum ('professor_aluno','org_professor');
exception when duplicate_object then null; end $$;

do $$ begin
  create type origem_rotina as enum ('propria','atribuida');
exception when duplicate_object then null; end $$;

-- ============================================================
-- 2. owner_user_id denormalizado nas tabelas filhas
--    (routine_exercises, set_logs nao tem user_id direto).
--    Usado APENAS para o filtro de dono no sync do cliente
--    (ver lib/core/sync/sync_engine.dart). RLS continua via parent.
-- ============================================================
alter table public.routine_exercises
  add column if not exists owner_user_id uuid references public.users(id);
alter table public.set_logs
  add column if not exists owner_user_id uuid references public.users(id);

-- Backfill a partir do parent
update public.routine_exercises re
  set owner_user_id = r.user_id
  from public.routines r
  where re.routine_id = r.id and re.owner_user_id is null;

update public.set_logs sl
  set owner_user_id = s.user_id
  from public.workout_sessions s
  where sl.session_id = s.id and sl.owner_user_id is null;

-- Triggers para manter owner_user_id em sync com o parent
create or replace function public.set_re_owner()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  select user_id into new.owner_user_id
    from public.routines where id = new.routine_id;
  return new;
end;
$$;

drop trigger if exists trg_re_owner on public.routine_exercises;
create trigger trg_re_owner
  before insert or update of routine_id on public.routine_exercises
  for each row execute function public.set_re_owner();

create or replace function public.set_setlog_owner()
returns trigger language plpgsql security definer
set search_path = public as $$
begin
  select user_id into new.owner_user_id
    from public.workout_sessions where id = new.session_id;
  return new;
end;
$$;

drop trigger if exists trg_setlog_owner on public.set_logs;
create trigger trg_setlog_owner
  before insert or update of session_id on public.set_logs
  for each row execute function public.set_setlog_owner();

create index if not exists idx_re_owner on public.routine_exercises (owner_user_id);
create index if not exists idx_setlog_owner on public.set_logs (owner_user_id);

-- ============================================================
-- 3. organizacoes (academia) - opcional
-- ============================================================
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

-- ============================================================
-- 4. vinculos (professor <-> aluno) - nucleo
-- ============================================================
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

-- ============================================================
-- 5. convites
-- ============================================================
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

-- ============================================================
-- 6. routines: marca rotina atribuida pelo treinador
-- ============================================================
alter table public.routines
  add column if not exists origem origem_rotina not null default 'propria',
  add column if not exists atribuido_por uuid references public.users(id);

-- ============================================================
-- 7. Helper: o auth.uid() atual eh treinador ATIVO do aluno?
--    security definer p/ ler vinculos sem recursao de RLS.
-- ============================================================
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

-- ============================================================
-- 8. RLS das novas tabelas
-- ============================================================
alter table public.organizacoes        enable row level security;
alter table public.organizacao_membros enable row level security;
alter table public.vinculos            enable row level security;
alter table public.convites            enable row level security;

-- vinculos: professor ve os seus, aluno ve os seus
drop policy if exists vinculos_select on public.vinculos;
create policy vinculos_select on public.vinculos for select
  using (professor_id = auth.uid() or aluno_id = auth.uid());
drop policy if exists vinculos_prof_insert on public.vinculos;
create policy vinculos_prof_insert on public.vinculos for insert
  with check (professor_id = auth.uid());
drop policy if exists vinculos_update on public.vinculos;
create policy vinculos_update on public.vinculos for update
  using (professor_id = auth.uid() or aluno_id = auth.uid());

-- organizacoes: dono e membros ativos leem; dono escreve
drop policy if exists org_select on public.organizacoes;
create policy org_select on public.organizacoes for select
  using (
    dono_user_id = auth.uid()
    or exists (select 1 from public.organizacao_membros m
               where m.org_id = id and m.user_id = auth.uid()
                 and m.status = 'ativo')
  );
drop policy if exists org_owner_all on public.organizacoes;
create policy org_owner_all on public.organizacoes for all
  using (dono_user_id = auth.uid()) with check (dono_user_id = auth.uid());

drop policy if exists org_membros_select on public.organizacao_membros;
create policy org_membros_select on public.organizacao_membros for select
  using (user_id = auth.uid()
    or exists (select 1 from public.organizacoes o
               where o.id = org_id and o.dono_user_id = auth.uid()));

-- convites: criador gerencia (leitura por codigo so via RPC security definer)
drop policy if exists convites_owner on public.convites;
create policy convites_owner on public.convites for all
  using (criado_por = auth.uid()) with check (criado_por = auth.uid());

-- ============================================================
-- 9. Amplia RLS das tabelas do aluno p/ leitura do treinador.
--    (substituem as policies "owner" de 0001)
-- ============================================================

-- routines: dono OU treinador (leitura); treinador escreve so atribuidas
drop policy if exists routines_owner on public.routines;
drop policy if exists routines_select on public.routines;
create policy routines_select on public.routines for select
  using (user_id = auth.uid() or public.eh_treinador_de(user_id));
drop policy if exists routines_insert on public.routines;
create policy routines_insert on public.routines for insert
  with check (user_id = auth.uid() or public.eh_treinador_de(user_id));
drop policy if exists routines_update on public.routines;
create policy routines_update on public.routines for update
  using (
    user_id = auth.uid()
    or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid())
  )
  with check (
    user_id = auth.uid()
    or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid())
  );
drop policy if exists routines_delete on public.routines;
create policy routines_delete on public.routines for delete
  using (user_id = auth.uid()
    or (public.eh_treinador_de(user_id) and atribuido_por = auth.uid()));

-- routine_exercises: via dono da routine OU treinador
drop policy if exists routine_exercises_owner on public.routine_exercises;
drop policy if exists routine_exercises_rw on public.routine_exercises;
create policy routine_exercises_rw on public.routine_exercises for all
  using (exists (select 1 from public.routines r where r.id = routine_id
           and (r.user_id = auth.uid() or public.eh_treinador_de(r.user_id))))
  with check (exists (select 1 from public.routines r where r.id = routine_id
           and (r.user_id = auth.uid()
                or (public.eh_treinador_de(r.user_id)
                    and r.atribuido_por = auth.uid()))));

-- workout_sessions: dono escreve; treinador SO LE
drop policy if exists sessions_owner on public.workout_sessions;
drop policy if exists sessions_owner_rw on public.workout_sessions;
create policy sessions_owner_rw on public.workout_sessions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists sessions_coach_read on public.workout_sessions;
create policy sessions_coach_read on public.workout_sessions for select
  using (public.eh_treinador_de(user_id));

-- set_logs: dono escreve; treinador SO LE (via session)
drop policy if exists set_logs_owner on public.set_logs;
drop policy if exists set_logs_owner_rw on public.set_logs;
create policy set_logs_owner_rw on public.set_logs for all
  using (exists (select 1 from public.workout_sessions s
           where s.id = session_id and s.user_id = auth.uid()))
  with check (exists (select 1 from public.workout_sessions s
           where s.id = session_id and s.user_id = auth.uid()));
drop policy if exists set_logs_coach_read on public.set_logs;
create policy set_logs_coach_read on public.set_logs for select
  using (exists (select 1 from public.workout_sessions s
           where s.id = session_id and public.eh_treinador_de(s.user_id)));

-- cardio_sessions: dono escreve; treinador SO LE
drop policy if exists cardio_owner on public.cardio_sessions;
drop policy if exists cardio_owner_rw on public.cardio_sessions;
create policy cardio_owner_rw on public.cardio_sessions for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists cardio_coach_read on public.cardio_sessions;
create policy cardio_coach_read on public.cardio_sessions for select
  using (public.eh_treinador_de(user_id));

-- ============================================================
-- 10. RPC: criar convite (professor gera codigo)
-- ============================================================
create or replace function public.criar_convite(
  p_tipo tipo_convite default 'professor_aluno',
  p_org uuid default null,
  p_usos_max int default 1,
  p_validade_dias int default 7
)
returns public.convites language plpgsql security definer
set search_path = public as $$
declare
  v_codigo text;
  c public.convites;
  tentativas int := 0;
begin
  loop
    -- codigo curto legivel: 8 chars hex maiusculo, ex. 'A1B2-C3D4'
    v_codigo := upper(substr(encode(gen_random_bytes(4),'hex'),1,4))
             || '-' ||
                upper(substr(encode(gen_random_bytes(4),'hex'),1,4));
    exit when not exists (select 1 from public.convites where codigo = v_codigo);
    tentativas := tentativas + 1;
    if tentativas > 10 then
      raise exception 'falha ao gerar codigo unico';
    end if;
  end loop;

  insert into public.convites
    (codigo, tipo, criado_por, org_id, usos_max, expira_em)
  values
    (v_codigo, p_tipo, auth.uid(), p_org, greatest(p_usos_max, 1),
     now() + make_interval(days => greatest(p_validade_dias, 1)))
  returning * into c;
  return c;
end;
$$;

-- ============================================================
-- 11. RPC: resgatar convite (aluno/professor digita codigo)
-- ============================================================
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
  if c.criado_por = auth.uid() then
    raise exception 'voce nao pode resgatar o proprio convite';
  end if;

  if c.tipo = 'professor_aluno' then
    insert into public.vinculos
      (professor_id, aluno_id, org_id, status, aceito_em)
    values (c.criado_por, auth.uid(), c.org_id, 'ativo', now())
    on conflict do nothing
    returning * into v;
  else -- org_professor
    insert into public.organizacao_membros (org_id, user_id, papel, status)
    values (c.org_id, auth.uid(), 'professor', 'ativo')
    on conflict (org_id, user_id) do update set status = 'ativo';
  end if;

  update public.convites set
    usos = usos + 1,
    status = case when usos + 1 >= usos_max then 'expirado' else 'ativo' end
    where id = c.id;
  return v;
end;
$$;

-- ============================================================
-- Fim do schema 0002.
-- ============================================================
