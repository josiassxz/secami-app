-- Slug estável para o exercício (usado pelo app Flutter para resolver a
-- biblioteca local "seed:<slug>" para o uuid do catálogo global). Nulo =
-- ainda não reconciliado com a biblioteca do app (SPEC — nota de migração E9).
ALTER TABLE exercise ADD COLUMN slug text UNIQUE;

-- Timestamp de criação nas tabelas de treino do app (o cliente envia
-- "criado_em"; sem coluna própria a informação se perdia no INSERT).
ALTER TABLE routine ADD COLUMN criado_em timestamptz;
ALTER TABLE routine_exercise ADD COLUMN criado_em timestamptz;
ALTER TABLE set_log ADD COLUMN criado_em timestamptz;
