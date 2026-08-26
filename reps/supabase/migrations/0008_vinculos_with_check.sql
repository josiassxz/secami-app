-- ============================================================
-- 0008: hardening da RLS de vinculos
-- A policy de UPDATE tinha apenas USING (selecao de linha) e nenhum
-- WITH CHECK (validacao do valor escrito). Sem WITH CHECK, um cliente que
-- passa o teste de identidade poderia gravar valores arbitrarios nas colunas.
-- Espelha o padrao ja usado em vinculos_prof_insert (migration 0002).
-- ============================================================

drop policy if exists vinculos_update on public.vinculos;
create policy vinculos_update on public.vinculos for update
  using (professor_id = auth.uid() or aluno_id = auth.uid())
  with check (professor_id = auth.uid() or aluno_id = auth.uid());
