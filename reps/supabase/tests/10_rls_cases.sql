-- =============================================================
-- Casos de teste de isolamento RLS (professor <-> aluno).
-- Cada caso roda numa transacao propria: seta o "usuario logado" (GUC
-- request.jwt.claims) + assume o role `authenticated`, executa as queries
-- sob RLS e levanta exception em qualquer expectativa violada. Com
-- psql -v ON_ERROR_STOP=1, qualquer falha aborta o script (exit != 0).
--
-- Atores: P1=1111..., P2=2222..., A1=aaaa... (de P1), A2=bbbb... (de P2).
-- Vinculos: V1=c111... (P1-A1), V2=c222... (P2-A2).
-- =============================================================

-- CASE 1: P1 (treinador de A1) LE a sessao de A1 e SO ela.
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
set local role authenticated;
do $$
declare n int;
begin
  select count(*) into n from public.workout_sessions;
  if n <> 1 then
    raise exception 'CASE1 FAIL: P1 deveria ver 1 sessao (a de A1), viu %', n;
  end if;
  if not exists (select 1 from public.workout_sessions
                 where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') then
    raise exception 'CASE1 FAIL: P1 nao enxergou a sessao do aluno A1';
  end if;
end $$;
rollback;

-- CASE 2: A2 NAO le a sessao de A1 (aluno<->aluno isolado).
begin;
select set_config('request.jwt.claims',
  '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"}', true);
set local role authenticated;
do $$
declare n int;
begin
  if exists (select 1 from public.workout_sessions
             where user_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') then
    raise exception 'CASE2 FAIL: A2 conseguiu ler a sessao de A1';
  end if;
  select count(*) into n from public.workout_sessions; -- so a propria
  if n <> 1 then
    raise exception 'CASE2 FAIL: A2 deveria ver 1 (a propria), viu %', n;
  end if;
end $$;
rollback;

-- CASE 3: P2 (treinador de A2, NAO de A1) nao le set_logs de A1.
begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
set local role authenticated;
do $$
begin
  if exists (select 1 from public.set_logs
             where session_id = '50000000-0000-0000-0000-00000000000a') then
    raise exception 'CASE3 FAIL: P2 leu set_logs de A1 (nao e aluno dele)';
  end if;
end $$;
rollback;

-- CASE 4: P2 nao enxerga o vinculo P1-A1 (vinculos_select isolado).
begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
set local role authenticated;
do $$
declare n int;
begin
  if exists (select 1 from public.vinculos
             where id = 'c1111111-1111-1111-1111-111111111111') then
    raise exception 'CASE4 FAIL: P2 enxergou o vinculo P1-A1';
  end if;
  select count(*) into n from public.vinculos; -- so o seu (V2)
  if n <> 1 then
    raise exception 'CASE4 FAIL: P2 deveria ver 1 vinculo (o seu), viu %', n;
  end if;
end $$;
rollback;

-- CASE 5: professor NAO consegue reatribuir professor_id (sequestrar vinculo).
-- P1 tenta "doar" o vinculo trocando professor_id para P2. A USING deixa a
-- linha ser alvo (P1 e professor), e o novo valor e rejeitado.
--
-- IMPORTANTE (corrige a premissa do achado SEC-01 / plano 002): este invariante
-- ja era garantido pelo Postgres ANTES do 0008. Numa policy de UPDATE SEM
-- WITH CHECK, o Postgres aplica a expressao USING tambem a linha NOVA. Logo a
-- USING de 0002 ja negava este update. O WITH CHECK do 0008 (mesmo predicado)
-- e funcionalmente REDUNDANTE — torna a regra explicita, mas nao fecha buraco
-- nenhum. Validado pelo controle negativo: este caso passa com OU sem o 0008.
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
set local role authenticated;
do $$
begin
  begin
    update public.vinculos
       set professor_id = '22222222-2222-2222-2222-222222222222'
     where id = 'c1111111-1111-1111-1111-111111111111';
    raise exception
      'CASE5 FAIL: update reatribuindo professor_id NAO foi negado '
      '(WITH CHECK ausente?)';
  exception
    when insufficient_privilege then
      null; -- esperado: a WITH CHECK da RLS negou (SQLSTATE 42501)
  end;
end $$;
rollback;

-- CASE 6: controle positivo — P1 PODE encerrar o proprio vinculo.
-- Garante que a policy nao esta apenas negando tudo.
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
set local role authenticated;
do $$
begin
  update public.vinculos set status = 'encerrado'
   where id = 'c1111111-1111-1111-1111-111111111111';
  if not found then
    raise exception 'CASE6 FAIL: P1 nao conseguiu encerrar o proprio vinculo';
  end if;
end $$;
rollback;

-- CASE 7a: (migration 0003) P1 LE o registro public.users de A1 (nome/email).
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111"}', true);
set local role authenticated;
do $$
begin
  if not exists (select 1 from public.users
                 where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') then
    raise exception 'CASE7a FAIL: P1 nao leu o registro users do aluno A1';
  end if;
end $$;
rollback;

-- CASE 7b: P2 NAO le o registro users de A1 (sem vinculo).
begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222"}', true);
set local role authenticated;
do $$
begin
  if exists (select 1 from public.users
             where id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') then
    raise exception 'CASE7b FAIL: P2 leu o registro users de A1 (nao relacionado)';
  end if;
end $$;
rollback;

\echo '====================================='
\echo 'TODOS OS CASOS DE RLS PASSARAM (1..7b)'
\echo '====================================='
