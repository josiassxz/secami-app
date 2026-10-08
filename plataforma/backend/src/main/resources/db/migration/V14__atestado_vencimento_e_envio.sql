-- Vencimento do atestado (só alunos civis): vale 1 ano a partir da data do
-- atestado; sem ela, da data original de cadastro. cadastrado_em guarda essa
-- data original (base antiga = data de criação lá; plataforma = data do
-- cadastro aqui) — created_at é só quando o registro entrou neste banco.
ALTER TABLE student ADD COLUMN cadastrado_em date;
UPDATE student SET cadastrado_em = created_at::date WHERE legacy_id IS NULL;

-- Bloqueio automático por atestado vencido (distingue do bloqueio manual do
-- admin: a validação de um novo atestado só desfaz o automático).
ALTER TABLE student ADD COLUMN bloqueio_atestado boolean NOT NULL DEFAULT false;

-- Novo atestado enviado pelo aluno no app, aguardando validação do admin.
CREATE TABLE atestado_envio (
  id             uuid PRIMARY KEY DEFAULT uuidv7(),
  student_id     uuid NOT NULL REFERENCES student(id) ON DELETE CASCADE,
  arquivo_id     uuid NOT NULL REFERENCES media(id),
  emissao_data   date NOT NULL,
  medico_nome    text NOT NULL,
  medico_crm     text NOT NULL,
  medico_crm_uf  text NOT NULL,
  status         text NOT NULL DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'APROVADO', 'RECUSADO')),
  motivo_recusa  text,
  enviado_em     timestamptz NOT NULL DEFAULT now(),
  analisado_em   timestamptz,
  analisado_por  uuid REFERENCES app_user(id) ON DELETE SET NULL
);
CREATE INDEX idx_atestado_envio_student ON atestado_envio(student_id, enviado_em DESC);
-- No máximo um envio em análise por aluno.
CREATE UNIQUE INDEX uq_atestado_envio_pendente ON atestado_envio(student_id) WHERE status = 'PENDENTE';
