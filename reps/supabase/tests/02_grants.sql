-- =============================================================
-- Privilegios de tabela para o role `authenticated`.
-- Privilegio de tabela (GRANT) e RLS sao camadas separadas: o GRANT permite
-- o TIPO de operacao; a RLS filtra QUAIS linhas. No Supabase real isso vem do
-- bootstrap gerenciado; aqui concedemos para os testes rodarem como
-- `authenticated`. Roda DEPOIS das migrations (as tabelas precisam existir).
-- =============================================================

grant usage on schema public to authenticated, anon;

grant select, insert, update, delete
  on all tables in schema public to authenticated;

grant usage, select on all sequences in schema public to authenticated;

-- `authenticated` NAO e dono das tabelas nem superuser, entao a RLS e
-- aplicada normalmente sobre essas operacoes (que e o ponto do teste).
