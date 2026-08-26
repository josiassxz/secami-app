-- =============================================================
-- reps - schema inicial (Stage 1)
-- Gera as 7 tabelas do MVP, indices, triggers de updated_at e RLS.
-- Cole este arquivo inteiro no SQL Editor do Supabase e execute.
-- =============================================================

-- Extensoes necessarias
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================
-- Trigger generico de updated_at
-- ============================================================
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ============================================================
-- Enums em portugues (espelham docs/03-data-model.md)
-- ============================================================
do $$ begin
  create type grupo_muscular as enum (
    'peito','costas','ombros','biceps','triceps',
    'quadriceps','posterior','gluteos','panturrilha','core'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type padrao_movimento as enum (
    'puxada_vertical','puxada_horizontal',
    'empurrada_vertical','empurrada_horizontal',
    'agachamento','dobradica_quadril','isolador'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type equipamento as enum (
    'barra','halter','maquina','cabo',
    'peso_corporal','kettlebell','anilha'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type unidade_peso as enum ('kg','lb');
exception when duplicate_object then null; end $$;

do $$ begin
  create type unidade_distancia as enum ('km','mi');
exception when duplicate_object then null; end $$;

do $$ begin
  create type plano_usuario as enum ('free','pro');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_rotina as enum ('fixo','avulso');
exception when duplicate_object then null; end $$;

do $$ begin
  create type tipo_serie as enum ('normal','drop_set','superset','rest_pause');
exception when duplicate_object then null; end $$;

do $$ begin
  create type motivo_pulo_serie as enum (
    'equipamento_ocupado','fadiga','lesao','dor','outro'
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type modalidade_cardio as enum (
    'esteira','bicicleta','escada','corrida_ar_livre',
    'remo','eliptico','outros'
  );
exception when duplicate_object then null; end $$;

-- ============================================================
-- 1. users
-- ============================================================
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  nome text,
  unidade_peso unidade_peso not null default 'kg',
  unidade_distancia unidade_distancia not null default 'km',
  som_timer text default 'beep_padrao',
  vibracao_timer boolean not null default true,
  plano plano_usuario not null default 'free',
  criado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  device_id text
);

create trigger trg_users_updated_at
before update on public.users
for each row execute function public.set_updated_at();

-- Auto-inserir registro em public.users quando alguem se cadastra no auth.users
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, nome)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'nome', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- ============================================================
-- 2. exercises (biblioteca global + customizados)
-- ============================================================
create table if not exists public.exercises (
  id uuid primary key default uuid_generate_v4(),
  slug text unique not null,
  nome text not null,
  descricao text not null default '',
  gif_url text not null, -- guarda o slug do asset local
  grupo_muscular_primario grupo_muscular not null,
  grupo_muscular_secundario grupo_muscular[] not null default '{}',
  padrao_movimento padrao_movimento not null,
  equipamento equipamento not null,
  criado_por uuid references public.users(id) on delete cascade,
  arquivado boolean not null default false,
  criado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  device_id text
);

create index if not exists idx_exercises_grupo on public.exercises (grupo_muscular_primario);
create index if not exists idx_exercises_padrao on public.exercises (padrao_movimento);
create index if not exists idx_exercises_criado_por on public.exercises (criado_por);

create trigger trg_exercises_updated_at
before update on public.exercises
for each row execute function public.set_updated_at();

-- ============================================================
-- 3. routines
-- ============================================================
create table if not exists public.routines (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  nome text not null,
  tipo tipo_rotina not null default 'fixo',
  dias_da_semana int[] not null default '{}', -- 0=dom .. 6=sab
  ordem int not null default 0,
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  device_id text
);

create index if not exists idx_routines_user on public.routines (user_id);

create trigger trg_routines_updated_at
before update on public.routines
for each row execute function public.set_updated_at();

-- ============================================================
-- 4. routine_exercises
-- ============================================================
create table if not exists public.routine_exercises (
  id uuid primary key default uuid_generate_v4(),
  routine_id uuid not null references public.routines(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id) on delete restrict,
  ordem int not null default 0,
  series_planejadas jsonb not null default '[]'::jsonb,
  notas text,
  criado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  device_id text
);

create index if not exists idx_routine_exercises_routine
  on public.routine_exercises (routine_id, ordem);

create trigger trg_routine_exercises_updated_at
before update on public.routine_exercises
for each row execute function public.set_updated_at();

-- ============================================================
-- 5. workout_sessions
-- ============================================================
create table if not exists public.workout_sessions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  routine_id uuid references public.routines(id) on delete set null,
  iniciado_em timestamptz not null default now(),
  finalizado_em timestamptz,
  duracao_total_segundos int,
  notas text,
  sentimento int check (sentimento between 1 and 5),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  device_id text
);

create index if not exists idx_sessions_user_iniciado
  on public.workout_sessions (user_id, iniciado_em desc);

create trigger trg_workout_sessions_updated_at
before update on public.workout_sessions
for each row execute function public.set_updated_at();

-- ============================================================
-- 6. set_logs
-- ============================================================
create table if not exists public.set_logs (
  id uuid primary key default uuid_generate_v4(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  ordem_no_treino int not null,
  numero_serie int not null,
  reps_realizadas int,
  carga_kg numeric(7,2),
  rpe int check (rpe between 1 and 10),
  tipo_serie tipo_serie not null default 'normal',
  executada boolean not null default true,
  motivo_pulo motivo_pulo_serie,
  substituido_de_exercise_id uuid references public.exercises(id),
  criado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  device_id text
);

create index if not exists idx_set_logs_session on public.set_logs (session_id);
create index if not exists idx_set_logs_exercise on public.set_logs (exercise_id);

create trigger trg_set_logs_updated_at
before update on public.set_logs
for each row execute function public.set_updated_at();

-- ============================================================
-- 7. cardio_sessions
-- ============================================================
create table if not exists public.cardio_sessions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  modalidade modalidade_cardio not null,
  duracao_minutos int not null,
  distancia_km numeric(7,2),
  intensidade int check (intensidade between 1 and 10),
  fc_media int,
  fc_max int,
  calorias int,
  external_source text,
  external_id text,
  synced_at timestamptz,
  executado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  device_id text
);

create index if not exists idx_cardio_user_executado
  on public.cardio_sessions (user_id, executado_em desc);

create trigger trg_cardio_sessions_updated_at
before update on public.cardio_sessions
for each row execute function public.set_updated_at();

-- ============================================================
-- Row-Level Security
-- ============================================================
alter table public.users enable row level security;
alter table public.exercises enable row level security;
alter table public.routines enable row level security;
alter table public.routine_exercises enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.set_logs enable row level security;
alter table public.cardio_sessions enable row level security;

-- users: ler/escrever proprio
drop policy if exists users_select_self on public.users;
create policy users_select_self on public.users
  for select using (id = auth.uid());

drop policy if exists users_update_self on public.users;
create policy users_update_self on public.users
  for update using (id = auth.uid()) with check (id = auth.uid());

-- exercises: biblioteca global (criado_por null) eh public read.
-- Customizados: so o dono ve.
drop policy if exists exercises_select on public.exercises;
create policy exercises_select on public.exercises
  for select using (
    criado_por is null or criado_por = auth.uid()
  );

drop policy if exists exercises_insert_own on public.exercises;
create policy exercises_insert_own on public.exercises
  for insert with check (criado_por = auth.uid());

drop policy if exists exercises_update_own on public.exercises;
create policy exercises_update_own on public.exercises
  for update using (criado_por = auth.uid())
  with check (criado_por = auth.uid());

drop policy if exists exercises_delete_own on public.exercises;
create policy exercises_delete_own on public.exercises
  for delete using (criado_por = auth.uid());

-- helper: ownership check para tabelas que dependem de user_id direto
-- routines
drop policy if exists routines_owner on public.routines;
create policy routines_owner on public.routines
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- routine_exercises (via routine)
drop policy if exists routine_exercises_owner on public.routine_exercises;
create policy routine_exercises_owner on public.routine_exercises
  for all using (
    exists (
      select 1 from public.routines r
      where r.id = routine_id and r.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.routines r
      where r.id = routine_id and r.user_id = auth.uid()
    )
  );

-- workout_sessions
drop policy if exists sessions_owner on public.workout_sessions;
create policy sessions_owner on public.workout_sessions
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- set_logs (via session)
drop policy if exists set_logs_owner on public.set_logs;
create policy set_logs_owner on public.set_logs
  for all using (
    exists (
      select 1 from public.workout_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.workout_sessions s
      where s.id = session_id and s.user_id = auth.uid()
    )
  );

-- cardio_sessions
drop policy if exists cardio_owner on public.cardio_sessions;
create policy cardio_owner on public.cardio_sessions
  for all using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- Fim do schema 0001.
-- Para popular a biblioteca, execute a seguir o arquivo:
--   supabase/seeds/0001_exercises_seed.sql
-- ============================================================
