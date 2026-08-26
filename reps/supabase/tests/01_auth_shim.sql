-- =============================================================
-- Shim do ambiente Supabase para rodar as migrations num Postgres puro.
-- Recria o minimo do schema `auth` (users + uid()) e os roles que as
-- policies referenciam, para que as migrations 0001..0008 apliquem sem o
-- stack gerenciado do Supabase.
--
-- NAO faz parte do schema de producao — existe so para o harness de teste
-- de RLS (supabase/tests/run_rls_tests.sh). Roda como superuser (postgres).
-- =============================================================

-- Extensoes que as migrations usam (idempotente; 0001 tambem as cria).
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- Roles do Supabase que as policies referenciam.
-- Ex.: 0005_recommender_runs.sql tem `... to authenticated`, entao o role
-- precisa existir ANTES de aplicar as migrations.
do $$ begin
  create role anon nologin noinherit;
exception when duplicate_object then null; end $$;

do $$ begin
  create role authenticated nologin noinherit;
exception when duplicate_object then null; end $$;

do $$ begin
  create role service_role nologin noinherit bypassrls;
exception when duplicate_object then null; end $$;

-- Schema auth + tabela minima de usuarios (FK de public.users e trigger
-- on_auth_user_created dependem dela). So as colunas que o trigger le.
create schema if not exists auth;

create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text unique,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);

-- auth.uid(): no Supabase real le o claim `sub` do JWT. Aqui le o GUC de
-- sessao `request.jwt.claims` (o mesmo nome que o PostgREST usa). Os testes
-- setam esse GUC para simular "logado como" um usuario.
create or replace function auth.uid()
returns uuid
language sql
stable
as $$
  select nullif(
    current_setting('request.jwt.claims', true)::jsonb ->> 'sub', ''
  )::uuid;
$$;
