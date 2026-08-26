import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);

  // Get current time in Brazil (UTC-3)
  const now = new Date();
  const brNow = new Date(now.toLocaleString('en-US', { timeZone: 'America/Sao_Paulo' }));

  const today = brNow.toISOString().split('T')[0];
  const curMinutes = brNow.getHours() * 60 + brNow.getMinutes();

  // Target: appointments starting between 57 and 62 minutes from now
  // (runs every 5 min, so each slot is hit exactly once)
  const minTarget = curMinutes + 57;
  const maxTarget = curMinutes + 62;

  const appointments = await base44.asServiceRole.entities.Appointment.filter({ date: today });

  const toRemind = appointments.filter(a => {
    if (a.status === 'cancelado') return false;
    const [h, m] = a.slot_start.split(':').map(Number);
    const slotMinutes = h * 60 + m;
    return slotMinutes >= minTarget && slotMinutes <= maxTarget;
  });

  if (toRemind.length === 0) {
    return Response.json({ sent: 0, message: 'Nenhum agendamento no intervalo alvo.' });
  }

  // Fetch students to get their emails
  const studentIds = [...new Set(toRemind.map(a => a.student_id))];
  const students = await base44.asServiceRole.entities.Student.list();
  const studentMap = {};
  for (const s of students) {
    studentMap[s.id] = s;
  }

  let sent = 0;
  for (const appt of toRemind) {
    const student = studentMap[appt.student_id];
    const email = student?.email;
    if (!email) continue;

    await base44.asServiceRole.integrations.Core.SendEmail({
      to: email,
      subject: '⏰ Lembrete: seu treino começa em 1 hora!',
      body: `Olá, ${appt.student_name}!\n\nEste é um lembrete de que você tem um agendamento hoje às ${appt.slot_start}–${appt.slot_end} na Academia SECAMI.\n\nNão se esqueça de trazer seu atestado médico, se necessário.\n\nBom treino! 💪\n\nAcademia SECAMI`,
    });
    sent++;
  }

  return Response.json({ sent, message: `${sent} lembrete(s) enviado(s).` });
});