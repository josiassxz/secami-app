-- ============================================================
-- 0013 - Retencao de client_logs: 30 dias
-- Minimiza passivo de dados (mensagens de erro, mesmo redigidas) e limita
-- crescimento. Sem pg_cron, a limpeza fica documentada para scheduler externo.
-- ============================================================
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule(
      'client_logs_retencao', '17 3 * * *',
      $job$delete from public.client_logs where criado_em < now() - interval '30 days'$job$
    );
  else
    raise notice 'pg_cron ausente: agendar limpeza de client_logs externamente';
  end if;
end $$;
