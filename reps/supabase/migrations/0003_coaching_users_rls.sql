-- =============================================================
-- reps - Stage 4 (E4.2): leitura cruzada de users por vinculo
--
-- A RLS de 0001 (users_select_self) so deixa o usuario ler o proprio
-- registro. Para o professor listar seus alunos (nome/email) e o aluno
-- ver quem o acompanha, adicionamos uma policy ADITIVA de SELECT em
-- public.users baseada no vinculo ativo. Policies permissivas se somam (OR),
-- entao users_select_self continua valendo.
--
-- Design: docs/stages/stage-04-coaching.md
-- =============================================================

-- auth.uid() atual eh ALUNO ativo do professor p_prof?
create or replace function public.eh_aluno_de(p_prof uuid)
returns boolean language sql stable security definer
set search_path = public as $$
  select exists (
    select 1 from public.vinculos v
    where v.aluno_id = auth.uid()
      and v.professor_id = p_prof
      and v.status = 'ativo'
      and v.deleted_at is null
  );
$$;

-- Leitura de users relacionados por vinculo ativo (professor<->aluno).
drop policy if exists users_select_rel on public.users;
create policy users_select_rel on public.users for select
  using (
    public.eh_treinador_de(id)  -- sou treinador deste user (ele e meu aluno)
    or public.eh_aluno_de(id)   -- sou aluno deste user (ele e meu treinador)
  );

-- ============================================================
-- Fim do schema 0003.
-- ============================================================
