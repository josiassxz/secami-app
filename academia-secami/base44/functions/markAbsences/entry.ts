import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);

  // Timezone offset Brazil (UTC-3)
  const now = new Date();
  const brOffset = -3 * 60;
  const brNow = new Date(now.getTime() + (brOffset - now.getTimezoneOffset()) * 60000);

  const today = brNow.toISOString().slice(0, 10);
  const currentTime = brNow.toTimeString().slice(0, 5); // HH:MM

  // Get today's AND past scheduled appointments (still marked as 'agendado')
  const allAppointments = await base44.asServiceRole.entities.Appointment.filter({ status: 'agendado' });
  const appointments = allAppointments.filter(a => a.date <= today);

  // Get all check-ins for students with pending appointments
  const checkins = await base44.asServiceRole.entities.CheckIn.list();
  const checkedInAppointmentIds = new Set(checkins.map(c => c.appointment_id).filter(Boolean));
  const checkedInStudentIds = new Set(checkins.map(c => c.student_id));

  let marked = 0;

  for (const appt of appointments) {
    // Past days: check if student had a check-in on that specific date
    if (appt.date < today) {
      const hasCheckin = checkins.some(c => c.student_id === appt.student_id && c.date === appt.date);
      if (!hasCheckin) {
        await base44.asServiceRole.entities.Appointment.update(appt.id, { status: 'faltou' });
        marked++;
      }
      continue;
    }

    // Today: Check if 15 minutes have passed since slot_start
    const [slotH, slotM] = appt.slot_start.split(':').map(Number);
    const slotMinutes = slotH * 60 + slotM;
    const [curH, curM] = currentTime.split(':').map(Number);
    const curMinutes = curH * 60 + curM;

    if (curMinutes < slotMinutes + 60) continue;

    // Check if student has checked in on this specific date
    const hasCheckin = checkins.some(c => c.student_id === appt.student_id && c.date === appt.date);
    if (hasCheckin) continue;

    await base44.asServiceRole.entities.Appointment.update(appt.id, { status: 'faltou' });
    marked++;
  }

  return Response.json({ success: true, marked, checked_at: currentTime });
});