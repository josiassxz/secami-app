-- Unifica entrada e saída numa única categoria no Accelero (1213819408):
-- militar recebe vitalícia na aprovação, civil recebe só por agendamento
-- (janela dinâmica de 20min antes até 5h depois do início). Renomeia a
-- coluna de vínculo (não é mais só "entrada") e adiciona o horário de
-- expiração, usado pelo job que remove o acesso do civil depois que a
-- janela passa (ver AcceleroExpiracaoService).
ALTER TABLE appointment
  RENAME COLUMN accelero_entrada_vinculo_id TO accelero_acesso_vinculo_id;

ALTER TABLE appointment
  ADD COLUMN accelero_acesso_expira_em timestamptz;
