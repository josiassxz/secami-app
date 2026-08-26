-- ============================================================
-- 0012 - criar_convite: exige posse da organizacao (guard de tenant)
--
-- criar_convite (0002, secao 10; search_path corrigido em 0011) e SECURITY
-- DEFINER e aceitava `p_org` arbitrario sem checar quem chama. Qualquer
-- usuario autenticado podia emitir um convite `org_professor` apontando para
-- a organizacao de terceiros; ao resgatar (resgatar_convite, 0002 secao 11),
-- o codigo insere a linha em organizacao_membros com status 'ativo' e papel
-- professor -> o invasor vira membro professor ativo de org alheia. Furo de
-- isolamento de tenant.
--
-- Fix: antes de gerar o codigo, exigir que o emissor seja o dono da org
-- (public.eh_dono_org, 0010). Se `p_org` vier preenchido e o chamador nao
-- for dono -> excecao. Convite `org_professor` sem org tambem e rejeitado
-- (nao faz sentido e o resgate falharia com org_id null).
--
-- Redefine a funcao IDENTICA a 0011 (incl. search_path = public, extensions),
-- adicionando apenas o guard no inicio do corpo. Imutaveis: 0002 e 0011.
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
  -- Convite atrelado a organizacao exige que o emissor seja o dono dela.
  -- Sem este guard, qualquer autenticado emitia convite org_professor para
  -- org alheia e o resgate inseria membro ativo (furo de tenant).
  if p_org is not null and not public.eh_dono_org(p_org) then
    raise exception 'apenas o dono da organizacao pode criar convites dela';
  end if;
  if p_tipo = 'org_professor' and p_org is null then
    raise exception 'convite org_professor exige organizacao';
  end if;

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
