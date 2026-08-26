import { createClientFromRequest } from 'npm:@base44/sdk@0.8.25';

Deno.serve(async (req) => {
  try {
    const base44 = createClientFromRequest(req);
    const body = await req.json();

    const frequencia = body?.data || {};
    const { student_id, tipo, data_hora } = frequencia;

    if (!student_id || !tipo || !data_hora) {
      return Response.json({ erro: "Dados incompletos na frequencia" }, { status: 400 });
    }

    // Data e hora do evento
    const eventoDate = new Date(data_hora);
    const dataStr = eventoDate.toISOString().slice(0, 10); // yyyy-MM-dd
    const horaStr = `${String(eventoDate.getUTCHours()).padStart(2, '0')}:${String(eventoDate.getUTCMinutes()).padStart(2, '0')}`;

    // Busca agendamento ativo do aluno no dia
    const appointments = await base44.asServiceRole.entities.Appointment.filter({
      student_id,
      date: dataStr,
    });

    const agendamento = appointments.find(a => a.status === 'agendado' || a.status === 'confirmado');

    if (!agendamento) {
      return Response.json({ aviso: "Nenhum agendamento ativo encontrado para este aluno na data", data: dataStr });
    }

    if (tipo === 'entrada') {
      // Verifica se já existe check-in
      const existing = await base44.asServiceRole.entities.CheckIn.filter({
        student_id,
        date: dataStr,
      });

      if (existing.length > 0) {
        return Response.json({ aviso: "Check-in já registrado para este dia", checkin_id: existing[0].id });
      }

      // Cria o check-in
      const checkin = await base44.asServiceRole.entities.CheckIn.create({
        student_id,
        student_name: frequencia.student_name || '',
        appointment_id: agendamento.id,
        date: dataStr,
        check_in_time: horaStr,
      });

      // Atualiza agendamento para confirmado
      await base44.asServiceRole.entities.Appointment.update(agendamento.id, { status: 'confirmado' });

      return Response.json({ success: true, acao: "checkin", checkin_id: checkin.id });

    } else if (tipo === 'saida') {
      // Busca o check-in existente para registrar checkout
      const checkins = await base44.asServiceRole.entities.CheckIn.filter({
        student_id,
        date: dataStr,
      });

      if (checkins.length === 0) {
        return Response.json({ aviso: "Nenhum check-in encontrado para registrar saída" });
      }

      const checkin = checkins[0];

      // Atualiza o check-out
      await base44.asServiceRole.entities.CheckIn.update(checkin.id, {
        check_out_time: horaStr,
      });

      return Response.json({ success: true, acao: "checkout", checkin_id: checkin.id });
    }

    return Response.json({ erro: "tipo_evento inválido. Use 'entrada' ou 'saida'" }, { status: 400 });

  } catch (error) {
    return Response.json({ erro: error.message }, { status: 500 });
  }
});