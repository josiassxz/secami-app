-- ============================================================
-- 0010 - Corrige recursao de RLS entre organizacoes e organizacao_membros
--
-- As policies de 0002 se referenciavam mutuamente:
--   org_select (organizacoes)        -> le organizacao_membros
--   org_membros_select (membros)     -> le organizacoes
-- Cada uma disparava a policy da outra -> Postgres levanta
--   42P17 "infinite recursion detected in policy for relation ...".
-- Efeito: TODA leitura de organizacoes falha, inclusive o embed
--   `org:organizacoes(nome)` usado em vinculos (Meu treinador / Minha
--   academia).
--
-- Fix: mover as checagens cruzadas para funcoes SECURITY DEFINER (mesmo
-- padrao de eh_treinador_de em 0002, secao 7). Como definer bypassa RLS,
-- a leitura interna nao re-dispara a policy da outra tabela -> sem recursao.
-- ============================================================

-- auth.uid() atual eh membro ATIVO da organizacao? (le membros sem RLS)
create or replace function public.eh_membro_org_ativo(p_org uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.organizacao_membros m
    where m.org_id = p_org
      and m.user_id = auth.uid()
      and m.status = 'ativo'
  );
$$;

-- auth.uid() atual eh dono da organizacao? (le organizacoes sem RLS)
create or replace function public.eh_dono_org(p_org uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.organizacoes o
    where o.id = p_org
      and o.dono_user_id = auth.uid()
  );
$$;

-- Recria as policies usando os helpers (sem exists inline cruzado).
drop policy if exists org_select on public.organizacoes;
create policy org_select on public.organizacoes for select
  using (
    dono_user_id = auth.uid()
    or public.eh_membro_org_ativo(id)
  );

drop policy if exists org_membros_select on public.organizacao_membros;
create policy org_membros_select on public.organizacao_membros for select
  using (
    user_id = auth.uid()
    or public.eh_dono_org(org_id)
  );
