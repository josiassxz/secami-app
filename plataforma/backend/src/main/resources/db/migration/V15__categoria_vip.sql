-- Categoria "VIP": aluno com as mesmas regras do Militar — catraca liberada
-- sempre (categoria vitalícia no Accelero), sem depender de agendamento e
-- fora da regra de vencimento do atestado.
ALTER TABLE student DROP CONSTRAINT student_student_type_check;
ALTER TABLE student ADD CONSTRAINT student_student_type_check
  CHECK (student_type IN ('Civil', 'Militar', 'VIP', 'Instrutor'));
