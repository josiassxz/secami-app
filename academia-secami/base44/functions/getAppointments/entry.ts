import { createClientFromRequest } from 'npm:@base44/sdk@0.8.25';

Deno.serve(async (req) => {
  try {
    const base44 = createClientFromRequest(req);
    const body = await req.json();

    const { student_id } = body;

    if (!student_id) {
      return Response.json({ erro: "student_id obrigatório" }, { status: 400 });
    }

    // Busca todos os agendamentos ativos (agendado ou confirmado) do aluno
    const appointments = await base44.asServiceRole.entities.Appointment.filter({
      student_id,
    });

    const ativos = appointments.filter(a =>
      a.status === 'agendado' || a.status === 'confirmado'
    );

    // Busca dados do aluno
    const students = await base44.asServiceRole.entities.Student.filter({ id: student_id });
    const student = students[0] || null;

    return Response.json({
      success: true,
      student: student ? {
        id: student.id,
        full_name: student.full_name,
        cpf: student.cpf,
        matricula: student.matricula,
        student_type: student.student_type,
        email: student.email,
        phone: student.phone,
      } : null,
      appointments: ativos.map(a => ({
        id: a.id,
        date: a.date,
        slot_start: a.slot_start,
        slot_end: a.slot_end,
        status: a.status,
      })),
      total: ativos.length,
    });
  } catch (error) {
    return Response.json({ erro: error.message }, { status: 500 });
  }
});