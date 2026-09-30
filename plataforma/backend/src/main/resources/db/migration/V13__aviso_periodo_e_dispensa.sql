-- Avisos como janela no aplicativo: cada aviso ganha um período de exibição
-- opcional (datas inclusive; nulo = sem limite daquele lado) e cada usuário
-- pode marcar "não mostrar novamente" — guardado aqui, por usuário, pra valer
-- em qualquer aparelho/navegador em que ele entrar.
ALTER TABLE notice
  ADD COLUMN exibir_de date,
  ADD COLUMN exibir_ate date;
ALTER TABLE notice ADD CONSTRAINT notice_periodo_check
  CHECK (exibir_de IS NULL OR exibir_ate IS NULL OR exibir_de <= exibir_ate);

CREATE TABLE notice_dispensa (
  notice_id      uuid NOT NULL REFERENCES notice(id) ON DELETE CASCADE,
  user_id        uuid NOT NULL REFERENCES app_user(id) ON DELETE CASCADE,
  dispensado_em  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (notice_id, user_id)
);
CREATE INDEX idx_notice_dispensa_user ON notice_dispensa(user_id);
