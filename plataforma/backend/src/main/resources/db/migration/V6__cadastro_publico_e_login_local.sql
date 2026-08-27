-- Login passa a ser 100% e-mail/senha (LDAP removido) e o aluno civil pode se
-- auto-cadastrar pelo formulário público (dados do PAR-Q + atestado médico
-- em PDF), ficando pendente de aprovação do admin/gerente até liberar acesso.

-- E-mail vira a chave de login: único (case-insensitive via lower()), mas
-- permanece opcional na coluna em si (nem todo app_user já tem e-mail hoje —
-- os alunos migrados via CSV não têm login ainda, só os 486 registros).
CREATE UNIQUE INDEX idx_app_user_email_lower ON app_user (lower(email))
  WHERE email IS NOT NULL AND email <> '';

-- Novo tipo de mídia: atestado médico anexado no cadastro público.
ALTER TABLE media DROP CONSTRAINT media_tipo_check;
ALTER TABLE media ADD CONSTRAINT media_tipo_check
  CHECK (tipo IN ('foto_aluno', 'exercicio', 'atestado_medico'));

ALTER TABLE student
  ADD COLUMN objetivos jsonb NOT NULL DEFAULT '[]',
  ADD COLUMN par_q jsonb,
  ADD COLUMN termo_responsabilidade_aceito_em timestamptz,
  ADD COLUMN termo_ciencia_aceito_em timestamptz,
  ADD COLUMN medico_nome text,
  ADD COLUMN medico_crm text,
  ADD COLUMN medico_crm_uf text,
  ADD COLUMN atestado_emissao_data date,
  ADD COLUMN atestado_arquivo_id uuid REFERENCES media(id) ON DELETE SET NULL,
  -- Todo aluno pré-existente (migração/cadastro manual do admin) já está
  -- liberado; só o auto-cadastro novo nasce pendente.
  ADD COLUMN status_cadastro text NOT NULL DEFAULT 'aprovado'
    CHECK (status_cadastro IN ('pendente', 'aprovado', 'rejeitado')),
  ADD COLUMN motivo_rejeicao text;

CREATE INDEX idx_student_status_cadastro ON student(status_cadastro)
  WHERE status_cadastro = 'pendente';
