-- ============================================================
-- 0011 - criar_convite: inclui schema `extensions` no search_path
--
-- criar_convite (0002, secao 10) chama gen_random_bytes() do pgcrypto no
-- corpo da funcao. No Supabase o pgcrypto vive no schema `extensions`, mas a
-- funcao fixa `search_path = public`; o plpgsql resolve o nome em runtime e
-- nao encontra -> 42883 "function gen_random_bytes(integer) does not exist".
-- (O default uuid_generate_v4() da coluna id NAO e afetado: default de coluna
-- e resolvido por OID no DDL, independente do search_path de execucao.)
--
-- Fix: search_path = public, extensions. Idempotente e seguro mesmo se a
-- extensao estiver em public (a ordem so amplia o caminho de busca).
-- Redefine a funcao identica a 0002, mudando apenas o search_path.
-- ============================================================

create or replace function public.criar_convite(
  p_tipo tipo_convite default 'professor_aluno',
  p_org uuid default null,
  p_usos_max int default 1,
  p_validade_dias int default 7
)
returns public.convites language plpgsql security definer
set search_path = public, extensions as $$
declare
  v_codigo text;
  c public.convites;
  tentativas int := 0;
begin
  loop
    -- codigo curto legivel: 8 chars hex maiusculo, ex. 'A1B2-C3D4'
    v_codigo := upper(substr(encode(gen_random_bytes(4),'hex'),1,4))
             || '-' ||
                upper(substr(encode(gen_random_bytes(4),'hex'),1,4));
    exit when not exists (select 1 from public.convites where codigo = v_codigo);
    tentativas := tentativas + 1;
    if tentativas > 10 then
      raise exception 'falha ao gerar codigo unico';
    end if;
  end loop;

  insert into public.convites
    (codigo, tipo, criado_por, org_id, usos_max, expira_em)
  values
    (v_codigo, p_tipo, auth.uid(), p_org, greatest(p_usos_max, 1),
     now() + make_interval(days => greatest(p_validade_dias, 1)))
  returning * into c;
  return c;
end;
$$;
