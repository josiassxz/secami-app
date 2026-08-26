-- ============================================================
-- Script consolidado: migrations pendentes 0005 + 0006 + 0007
-- (Stage 5 recomendador + Stage 6 circuito/tempo).
--
-- Como aplicar: cole TUDO no SQL Editor do projeto Supabase e Run.
-- Idempotente (if not exists / drop policy if exists) — seguro repetir.
-- Pré-requisito: 0001_init já aplicado (funções set_updated_at,
-- uuid_generate_v4 e tabela public.users). Se o schema de coaching
-- (0002/0003/0004) ainda não foi aplicado, aplique-o antes.
-- ============================================================

-- ----- 0005 — recommender_runs (registros auditáveis + RLS) -----
create table if not exists public.recommender_runs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  versao_regras text not null,
  perfil_json jsonb not null,
  triagem_json jsonb,                       -- dado de saúde: só com consentimento
  treino_json jsonb not null,
  divisao text,
  bloqueado boolean not null default false,
  criado_em timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  device_id text
);

create index if not exists idx_recommender_runs_user
  on public.recommender_runs (user_id, criado_em desc);

drop trigger if exists trg_recommender_runs_updated_at on public.recommender_runs;
create trigger trg_recommender_runs_updated_at
before update on public.recommender_runs
for each row execute function public.set_updated_at();

alter table public.recommender_runs enable row level security;

drop policy if exists recommender_runs_owner on public.recommender_runs;
create policy recommender_runs_owner on public.recommender_runs
  for all
  to authenticated                          -- explícito (hardening vs auth.role)
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ----- 0006 — exercício por tempo (set_logs.duracao_segundos) -----
alter table public.set_logs
  add column if not exists duracao_segundos int;

-- ----- 0007 — bi-set/circuito (routine_exercises) -----
alter table public.routine_exercises
  add column if not exists grupo_id uuid,
  add column if not exists grupo_tipo text not null default 'normal',
  add column if not exists rounds int;

create index if not exists idx_routine_exercises_grupo
  on public.routine_exercises (routine_id, grupo_id, ordem);

-- ----- Verificação rápida (rode após o Run acima) -----
-- select column_name from information_schema.columns
--   where table_name = 'set_logs' and column_name = 'duracao_segundos';
-- select column_name from information_schema.columns
--   where table_name = 'routine_exercises'
--     and column_name in ('grupo_id','grupo_tipo','rounds');
-- select policyname from pg_policies where tablename = 'recommender_runs';
