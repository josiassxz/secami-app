import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);

  const body = await req.json();

  // Payload from entity automation
  const eventType = body?.event?.type || 'unknown'; // 'create', 'update', 'delete'
  const appointmentData = body?.data || {};
  const oldData = body?.old_data || {};

  const studentId = appointmentData.student_id || oldData.student_id;
  
  // Busca dados do aluno para obter o CPF
  let studentCpf = '';
  if (studentId) {
    const students = await base44.asServiceRole.entities.Student.filter({ id: studentId });
    if (students.length > 0) {
      studentCpf = students[0].cpf || '';
    }
  }

  const dataToSend = {
    event: eventType,
    student_id: studentId,
    student_name: appointmentData.student_name || oldData.student_name,
    student_cpf: studentCpf,
    date: appointmentData.date || oldData.date,
    slot_start: appointmentData.slot_start || oldData.slot_start,
    slot_end: appointmentData.slot_end || oldData.slot_end,
    status: appointmentData.status || oldData.status,
    appointment_id: appointmentData.id || body?.event?.entity_id,
  };

  const response = await fetch("https://unchloridized-unsortable-tonda.ngrok-free.dev/webhook-agenda", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify(dataToSend),
  });

  const responseText = await response.text();

  return Response.json({
    success: response.ok,
    status: response.status,
    response: responseText,
  });
});