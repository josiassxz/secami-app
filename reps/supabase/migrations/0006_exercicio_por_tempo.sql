-- ============================================================
-- 0006 - Exercicio medido por tempo (Stage 6 / Feature B)
-- stage-06-circuit-timed.md, E1.
--
-- Series isometricas/por tempo (prancha, hollow hold, farmer carry)
-- registram a duracao executada em vez de repeticoes. A coluna
-- `duracao_segundos` em set_logs guarda essa duracao; fica NULL em
-- series medidas por repeticao.
--
-- O alvo de duracao por serie vive no JSON `series_planejadas` de
-- routine_exercises (campo `duracao_alvo_segundos`), sem alteracao de
-- schema. A flag `medida_por_tempo` do exercicio e definida no cliente
-- (exercisesSeed) — Storage/exercises nao muda no MVP.
-- ============================================================

alter table public.set_logs
  add column if not exists duracao_segundos int;
