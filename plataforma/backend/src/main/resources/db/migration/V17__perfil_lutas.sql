-- Perfil "Lutas": aluno civil que, nos dias da turma (Masculino ou Feminino),
-- tem a catraca liberada no horário da aula sem precisar agendar. Fora disso
-- agenda como civil.
ALTER TABLE student DROP CONSTRAINT student_student_type_check;
ALTER TABLE student ADD CONSTRAINT student_student_type_check
  CHECK (student_type IN ('Civil', 'Militar', 'VIP', 'Lutas', 'Instrutor'));
ALTER TABLE student ADD COLUMN turma_lutas text
  CHECK (turma_lutas IS NULL OR turma_lutas IN ('MASCULINO', 'FEMININO'));

-- Liberação do dia na catraca (uma por aluno/dia) — guarda o vínculo criado
-- no Accelero pra retirar quando a janela termina.
CREATE TABLE acesso_lutas (
    id                  uuid PRIMARY KEY DEFAULT uuidv7(),
    student_id          uuid NOT NULL REFERENCES student(id) ON DELETE CASCADE,
    data                date NOT NULL,
    accelero_vinculo_id text,
    expira_em           timestamptz NOT NULL,
    criado_em           timestamptz NOT NULL DEFAULT now(),
    UNIQUE (student_id, data)
);

-- Dias da semana: 1 = segunda ... 7 = domingo. Sexta (5) é mista.
INSERT INTO configuracao (chave, valor) VALUES
  ('lutas_masculino_dias', '2,4,5'),
  ('lutas_feminino_dias', '1,3,5'),
  ('lutas_inicio', '12:00'),
  ('lutas_fim', '13:00'),
  ('lutas_folga_saida_horas', '2');
