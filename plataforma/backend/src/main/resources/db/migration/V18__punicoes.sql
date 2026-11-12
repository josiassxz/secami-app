-- Punições aplicadas pelos instrutores de lutas aos alunos do perfil Lutas.
-- Papel novo "lutas" (instrutor de lutas) no login.
ALTER TABLE user_role DROP CONSTRAINT user_role_role_check;
ALTER TABLE user_role ADD CONSTRAINT user_role_role_check
  CHECK (role IN ('admin','gerente','recepcao','professor','aluno','lutas'));

-- Catálogo compartilhado (ex.: "10 flexões", "1 Coca-Cola").
CREATE TABLE punicao_item (
    id        uuid PRIMARY KEY DEFAULT uuidv7(),
    nome      text NOT NULL,
    ativo     boolean NOT NULL DEFAULT true,
    criado_em timestamptz NOT NULL DEFAULT now()
);

-- Punição aplicada: um ou mais itens (cópia dos nomes em `itens`, jsonb).
-- PENDENTE -> CUMPRIDA -> CONCLUIDA (fecha o ciclo e sai da lista).
CREATE TABLE punicao (
    id            uuid PRIMARY KEY DEFAULT uuidv7(),
    student_id    uuid NOT NULL REFERENCES student(id) ON DELETE CASCADE,
    itens         jsonb NOT NULL,
    observacao    text,
    status        text NOT NULL DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE','CUMPRIDA','CONCLUIDA')),
    aplicada_em   timestamptz NOT NULL DEFAULT now(),
    aplicada_por  uuid REFERENCES app_user(id) ON DELETE SET NULL,
    cumprida_em   timestamptz,
    cumprida_por  uuid REFERENCES app_user(id) ON DELETE SET NULL,
    concluida_em  timestamptz
);
CREATE INDEX idx_punicao_aluno ON punicao(student_id, status);

INSERT INTO configuracao (chave, valor) VALUES
  ('punicoes_por_ciclo', '2'),
  ('punicoes_dias_concluir', '30');

-- Marca, no cadastro do instrutor, que ele é instrutor de lutas (dá o papel "lutas").
ALTER TABLE student ADD COLUMN instrutor_lutas boolean NOT NULL DEFAULT false;
