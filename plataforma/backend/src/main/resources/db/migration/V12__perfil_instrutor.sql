-- Perfil "Instrutor": na aprovação do cadastro o admin pode escolher, em vez
-- de aluno (Civil/Militar), o perfil de instrutor — quem prescreve as fichas
-- de treino. O cadastro continua na tabela student (é onde ficam CPF,
-- contato e o vínculo com a catraca/Accelero), marcado com o tipo
-- 'Instrutor'; o login dele recebe o papel 'professor' (já existente no
-- RBAC) no lugar de 'aluno'.
ALTER TABLE student DROP CONSTRAINT student_student_type_check;
ALTER TABLE student ADD CONSTRAINT student_student_type_check
  CHECK (student_type IN ('Civil', 'Militar', 'Instrutor'));
