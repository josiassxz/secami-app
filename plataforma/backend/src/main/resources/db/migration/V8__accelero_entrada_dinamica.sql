-- Civil não tem mais entrada vitalícia (só a saída) — a entrada é liberada
-- dinamicamente no Accelero a cada agendamento (30min antes do início até o
-- fim do horário) e revogada se o agendamento for cancelado. Guardamos o
-- vínculo (UID da atribuição da categoria no Accelero, não o pctID) pra
-- saber exatamente o que revogar no cancelamento.
ALTER TABLE appointment
  ADD COLUMN accelero_entrada_vinculo_id varchar(32);
