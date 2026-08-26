-- ============================================================
-- 0005 - Recomendador de treinos: registros auditaveis
-- Stage 5 (stage-05-recommender). RN-050 (rastreabilidade),
-- RN-051 (dado de saude sensivel) e RN-052 (versionamento).
--
-- A sincronizacao deste registro para a nuvem so deve ocorrer com
-- consentimento explicito do usuario (RN-051). A coluna `triagem_json`
-- guarda dado de saude e fica NULL quando nao houve consentimento.
-- ============================================================

create table if not exists public.recommender_runs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade,
  versao_regras text not null,
  perfil_json jsonb not null,
  -- dado sensivel (saude): so preenchido com consentimento (RN-051)
  triagem_json jsonb,
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

-- RLS: somente o dono ve/edita seus registros (dado de saude).
alter table public.recommender_runs enable row level security;

drop policy if exists recommender_runs_owner on public.recommender_runs;
create policy recommender_runs_owner on public.recommender_runs
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
