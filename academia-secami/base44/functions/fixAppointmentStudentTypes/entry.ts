import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);

  const user = await base44.auth.me();
  if (user?.role !== 'admin') {
    return Response.json({ error: 'Acesso negado' }, { status: 403 });
  }

  // Busca todos os agendamentos
  const appointments = await base44.asServiceRole.entities.Appointment.list('-date', 2000);

  // Busca todos os alunos
  const students = await base44.asServiceRole.entities.Student.list('-created_date', 500);
  const studentMap = {};
  for (const s of students) {
    studentMap[s.id] = s.student_type || 'Civil';
  }

  let updated = 0;
  let skipped = 0;

  for (const appt of appointments) {
    const correctType = studentMap[appt.student_id];

    // Atualiza se student_type estiver ausente ou diferente do cadastro do aluno
    if (correctType && appt.student_type !== correctType) {
      await base44.asServiceRole.entities.Appointment.update(appt.id, { student_type: correctType });
      updated++;
    } else {
      skipped++;
    }
  }

  return Response.json({ success: true, updated, skipped });
});