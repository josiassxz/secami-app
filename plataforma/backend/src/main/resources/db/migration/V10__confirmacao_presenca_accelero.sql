-- Confirmação real de entrada/saída pela catraca (Accelero), pra além do
-- check-in autodeclarado — job periódico (AcceleroPresencaService) confere
-- o log de eventos reais dentro da janela liberada do agendamento e marca
-- aqui quando confirma. Usado pra permanência real e pra detectar falta de
-- verdade (agendou mas nunca passou pela catraca).
ALTER TABLE appointment
  ADD COLUMN entrada_confirmada_em timestamptz,
  ADD COLUMN saida_confirmada_em timestamptz;
