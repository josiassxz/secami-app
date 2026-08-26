import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);

  const [students, appointments, checkins, notices, blockedDates, slotConfigs, workoutLogs, workoutPlans, exercises] = await Promise.all([
    base44.asServiceRole.entities.Student.list('-created_date', 5000),
    base44.asServiceRole.entities.Appointment.list('-date', 5000),
    base44.asServiceRole.entities.CheckIn.list('-date', 5000),
    base44.asServiceRole.entities.Notice.list('-created_date', 1000),
    base44.asServiceRole.entities.BlockedDate.list('-date', 1000),
    base44.asServiceRole.entities.SlotConfig.list(),
    base44.asServiceRole.entities.WorkoutLog.list('-date', 5000),
    base44.asServiceRole.entities.WorkoutPlan.list('-created_date', 1000),
    base44.asServiceRole.entities.Exercise.list('-created_date', 1000),
  ]);

  const now = new Date().toLocaleString('pt-BR', { timeZone: 'America/Sao_Paulo' });

  const summary = `
=== BACKUP DIÁRIO - Academia SECAMI ===
Data/Hora: ${now}

📊 RESUMO:
- Alunos: ${students.length}
- Agendamentos: ${appointments.length}
- Check-ins: ${checkins.length}
- Avisos: ${notices.length}
- Datas Bloqueadas: ${blockedDates.length}
- Configurações de Slot: ${slotConfigs.length}
- Logs de Treino: ${workoutLogs.length}
- Fichas de Treino: ${workoutPlans.length}
- Exercícios: ${exercises.length}

Os dados completos estão no corpo abaixo em formato JSON.
`;

  const fullData = {
    backup_date: now,
    students,
    appointments,
    checkins,
    notices,
    blockedDates,
    slotConfigs,
    workoutLogs,
    workoutPlans,
    exercises,
  };

  await base44.asServiceRole.integrations.Core.SendEmail({
    to: 'funcionalpplt@gmail.com',
    subject: `Backup Diário Academia SECAMI - ${new Date().toLocaleDateString('pt-BR', { timeZone: 'America/Sao_Paulo' })}`,
    body: `${summary}\n\n=== DADOS COMPLETOS (JSON) ===\n\n${JSON.stringify(fullData, null, 2)}`,
  });

  const jsonSize = new TextEncoder().encode(JSON.stringify(fullData)).length;
  const sizeKB = (jsonSize / 1024).toFixed(2);
  const sizeMB = (jsonSize / 1024 / 1024).toFixed(2);

  return Response.json({
    success: true,
    message: 'Backup enviado com sucesso!',
    json_size: `${sizeKB} KB (${sizeMB} MB)`,
    counts: {
      students: students.length,
      appointments: appointments.length,
      checkins: checkins.length,
      notices: notices.length,
      blockedDates: blockedDates.length,
      slotConfigs: slotConfigs.length,
      workoutLogs: workoutLogs.length,
      workoutPlans: workoutPlans.length,
      exercises: exercises.length,
    },
  });
});