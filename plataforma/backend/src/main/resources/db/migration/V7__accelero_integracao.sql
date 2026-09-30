-- Integração com o Accelero (sistema que gerencia as catracas da academia):
-- ao aprovar um cadastro, o aluno é vinculado à pessoa correspondente no
-- Accelero (por CPF) e liberado nas categorias de entrada/saída conforme a
-- categoria (Civil/Militar). Guardamos o id da pessoa no Accelero pra não
-- precisar repesquisar por CPF a cada sincronização.
ALTER TABLE student
  ADD COLUMN accelero_pessoa_id varchar(32),
  ADD COLUMN accelero_liberado_em timestamptz;

CREATE INDEX idx_student_accelero_pessoa_id ON student (accelero_pessoa_id)
  WHERE accelero_pessoa_id IS NOT NULL;
