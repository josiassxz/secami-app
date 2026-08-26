-- ============================================================
-- 0009 - Logs de erro do cliente (diagnostico)
--
-- Sink append-only pra erros capturados no app (Observability.captureError).
-- Serve pra consultar server-side falhas de sync que, sem Sentry, ficariam
-- invisiveis no release (RLS, constraint, schema, uuid invalido).
--
-- Limite: erro por falta de rede (offline) nao chega aqui — e justamente a
-- ausencia de conexao. Offline e esperado/benigno; o que importa e o erro
-- em que o servidor rejeita a operacao, e esse a conexao existe.
-- ============================================================

create table if not exists public.client_logs (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.users(id) on delete cascade
    default auth.uid(),
  nivel text not null default 'error',
  hint text,
  mensagem text not null,
  plataforma text,
  app_versao text,
  criado_em timestamptz not null default now()
);

create index if not exists idx_client_logs_user
  on public.client_logs (user_id, criado_em desc);

-- RLS: cada um so insere e le os proprios logs. Sem update/delete
-- (append-only). Insert separado do select pra deixar a intencao explicita.
alter table public.client_logs enable row level security;

drop policy if exists client_logs_insere_proprio on public.client_logs;
create policy client_logs_insere_proprio on public.client_logs
  for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists client_logs_le_proprio on public.client_logs;
create policy client_logs_le_proprio on public.client_logs
  for select
  to authenticated
  using (user_id = auth.uid());
