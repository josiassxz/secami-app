-- =============================================================
-- Seed do cenario de teste de RLS. Roda como superuser (postgres), que
-- IGNORA RLS — entao aqui inserimos livremente o estado inicial.
--
-- Atores (UUIDs fixos para os casos referenciarem):
--   P1 = 11111111... professor    P2 = 22222222... professor
--   A1 = aaaaaaaa... aluno de P1   A2 = bbbbbbbb... aluno de P2
-- Vinculos ativos: V1 (P1<->A1), V2 (P2<->A2).
-- Cada aluno tem 1 sessao com 1 set_log.
-- =============================================================

-- Usuarios (insert em auth.users dispara on_auth_user_created -> public.users)
insert into auth.users (id, email, raw_user_meta_data) values
  ('11111111-1111-1111-1111-111111111111', 'p1@test.dev', '{"nome":"Prof 1"}'),
  ('22222222-2222-2222-2222-222222222222', 'p2@test.dev', '{"nome":"Prof 2"}'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a1@test.dev', '{"nome":"Aluno 1"}'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'a2@test.dev', '{"nome":"Aluno 2"}')
on conflict (id) do nothing;

-- Vinculos ativos professor<->aluno
insert into public.vinculos (id, professor_id, aluno_id, status, aceito_em) values
  ('c1111111-1111-1111-1111-111111111111',
   '11111111-1111-1111-1111-111111111111',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ativo', now()),
  ('c2222222-2222-2222-2222-222222222222',
   '22222222-2222-2222-2222-222222222222',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'ativo', now())
on conflict (id) do nothing;

-- Um exercicio global (criado_por null) para os set_logs referenciarem
insert into public.exercises
  (id, slug, nome, gif_url, grupo_muscular_primario, padrao_movimento,
   equipamento, criado_por)
values
  ('e0000000-0000-0000-0000-000000000000', 'supino', 'Supino', 'supino',
   'peito', 'empurrada_horizontal', 'barra', null)
on conflict (id) do nothing;

-- Uma sessao por aluno
insert into public.workout_sessions (id, user_id) values
  ('50000000-0000-0000-0000-00000000000a',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  ('50000000-0000-0000-0000-00000000000b',
   'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
on conflict (id) do nothing;

-- Um set_log por sessao (owner_user_id preenchido pelo trigger)
insert into public.set_logs
  (id, session_id, exercise_id, ordem_no_treino, numero_serie, carga_kg)
values
  ('60000000-0000-0000-0000-00000000000a',
   '50000000-0000-0000-0000-00000000000a',
   'e0000000-0000-0000-0000-000000000000', 0, 1, 50),
  ('60000000-0000-0000-0000-00000000000b',
   '50000000-0000-0000-0000-00000000000b',
   'e0000000-0000-0000-0000-000000000000', 0, 1, 60)
on conflict (id) do nothing;
