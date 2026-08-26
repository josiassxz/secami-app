-- ============================================================
-- 0014 - routines_insert: exige atribuido_por/origem do treinador
--
-- routines_insert (0002, secao routines) permitia ao treinador inserir na
-- conta do aluno com `with check (user_id = auth.uid() or
-- eh_treinador_de(user_id))` -- SEM exigir `atribuido_por = auth.uid()` nem
-- `origem = 'atribuida'`. Ja routines_update e routines_delete (mesma secao)
-- exigem os dois no ramo de treinador. Assimetria: um treinador podia inserir
-- rotina marcada `origem = 'propria'` / `atribuido_por = null`,
-- indistinguivel da rotina propria do aluno, e que as policies de
-- update/delete do treinador depois nao cobrem. Quebra a integridade da
-- atribuicao.
--
-- Fix: recriar SO routines_insert alinhando o ramo de treinador com
-- update/delete -- exigir `atribuido_por = auth.uid()` e `origem =
-- 'atribuida'`. O cliente legitimo (coach_repository.dart, atribuirRotina)
-- ja seta ambos ao inserir rotina de treinador, entao o fluxo real nao
-- quebra. O ramo do dono (`user_id = auth.uid()`) fica inalterado.
-- ============================================================

drop policy if exists routines_insert on public.routines;
create policy routines_insert on public.routines for insert
  with check (
    user_id = auth.uid()
    or (
      public.eh_treinador_de(user_id)
      and atribuido_por = auth.uid()
      and origem = 'atribuida'
    )
  );
