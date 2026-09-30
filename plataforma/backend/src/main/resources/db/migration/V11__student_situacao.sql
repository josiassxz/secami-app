ALTER TABLE student ADD COLUMN IF NOT EXISTS situacao VARCHAR(20) NOT NULL DEFAULT 'ATIVO';
UPDATE student SET situacao = CASE WHEN active THEN 'ATIVO' ELSE 'INATIVO' END WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_student_status_cadastro ON student(status_cadastro) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_student_situacao ON student(situacao) WHERE deleted_at IS NULL;