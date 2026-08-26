-- =============================================================
-- reps - Stage 4 (E4.5): leitura cruzada de users por organizacao
--
-- Permite o DONO da academia ler nome/email dos professores membros, e o
-- membro ler o dono. Policy aditiva (OR) sobre public.users; helpers em
-- security definer pra evitar recursao de RLS.
--
-- Design: docs/stages/stage-04-coaching.md
-- =============================================================

-- Sou dono de alguma org que tem p_membro como membro?
create or replace function public.eh_dono_de_org_com_membro(p_membro uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.organizacao_membros m
    join public.organizacoes o on o.id = m.org_id
    where m.user_id = p_membro
      and o.dono_user_id = auth.uid()
      and o.deleted_at is null
  );
$$;

-- Sou membro ativo de alguma org cujo dono e p_dono?
create or replace function public.compartilha_org_como_dono(p_dono uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.organizacoes o
    join public.organizacao_membros m on m.org_id = o.id
    where o.dono_user_id = p_dono
      and m.user_id = auth.uid()
      and m.status = 'ativo'
      and o.deleted_at is null
  );
$$;

drop policy if exists users_select_org on public.users;
create policy users_select_org on public.users for select
  using (
    public.eh_dono_de_org_com_membro(id)
    or public.compartilha_org_como_dono(id)
  );

-- ============================================================
-- Fim do schema 0004.
-- ============================================================
