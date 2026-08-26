import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);

  try {
    const user = await base44.auth.me();
    if (!user || !['admin', 'gerente'].includes(user.role)) {
      return Response.json({ error: 'Acesso negado: apenas Admin ou Gerente podem enviar e-mails.' }, { status: 403 });
    }

    const { subject, body } = await req.json();

    if (!subject || !body) {
      return Response.json({ error: 'Assunto e corpo do e-mail são obrigatórios.' }, { status: 400 });
    }

    const students = await base44.asServiceRole.entities.Student.filter({ active: true });
    const studentsWithEmail = students.filter(s => s.email && s.email.trim() !== '');

    let sentCount = 0;
    for (const student of studentsWithEmail) {
      await base44.integrations.Core.SendEmail({
        to: student.email,
        subject: subject,
        body: body,
        from_name: 'Academia Secami',
      });
      sentCount++;
    }

    return Response.json({ success: true, sentCount, total: studentsWithEmail.length });

  } catch (error) {
    console.error('Erro ao enviar e-mails:', error);
    return Response.json({ error: error.message }, { status: 500 });
  }
});