-- ============================================================
-- 0007 - Agrupamento bi-set / circuito (Stage 6 / Feature A)
-- stage-06-circuit-timed.md, A1.
--
-- Exercicios de uma rotina podem ser executados de forma intercalada:
--  - bi_set: 2+ exercicios encadeados sem descanso entre eles; descanso
--    so ao fechar a rodada (rodadas = nº de series do grupo).
--  - circuito: 2+ exercicios por N rodadas (coluna `rounds`).
-- Exercicios com o mesmo `grupo_id` formam um bloco. `grupo_tipo`='normal'
-- e o comportamento padrao (exercicio solo, serie a serie).
-- ============================================================

alter table public.routine_exercises
  add column if not exists grupo_id uuid,
  add column if not exists grupo_tipo text not null default 'normal',
  add column if not exists rounds int;

-- Indice para varrer membros de um grupo na ordem.
create index if not exists idx_routine_exercises_grupo
  on public.routine_exercises (routine_id, grupo_id, ordem);
