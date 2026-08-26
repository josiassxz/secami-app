import { createClientFromRequest } from 'npm:@base44/sdk@0.8.25';

Deno.serve(async (req) => {
  try {
    // 1. Valida a chave enviada pela catraca
    const apiKeyRecebida = req.headers.get('x-hardware-api-key') || '';
    const expectedKey = Deno.env.get('HARDWARE_API_KEY');

    if (!apiKeyRecebida || apiKeyRecebida !== expectedKey) {
      return Response.json({ success: false, erro: 'Não autorizado' }, { status: 401 });
    }

    // 2. Inicializa o cliente Base44
    const base44 = createClientFromRequest(req);

    // 3. 🔥 FUSO HORÁRIO TRAVADO EM GOIÂNIA: Garante que os agendamentos de hoje não sumam
    const hojeGoiania = new Date().toLocaleDateString('sv-SE', { timeZone: 'America/Sao_Paulo' });

    // 4. Busca em paralelo as duas tabelas para cruzar os dados com segurança
    const [appointments, allStudents] = await Promise.all([
      base44.asServiceRole.entities.Appointment.list(),
      base44.asServiceRole.entities.Student.list()
    ]);

    // 5. Filtra os agendamentos e injeta o CPF real de cada estudante
    const ativos = (appointments || [])
      .filter(a => {
        const statusValido = a.status === 'agendado' || a.status === 'confirmado';
        const dataValida = a.date >= hojeGoiania; // Traz apenas de hoje para a frente
        return statusValido && dataValida;
      })
      .map(a => {
        // Encontra o aluno correto comparando o ID do agendamento com o ID do cadastro do estudante
        const student = (allStudents || []).find(s => s.id === a.student_id);
        
        return {
          id: a.id,
          cpf: student ? student.cpf : null, // 🔥 Resgata o CPF real do cadastro do aluno
          date: a.date,
          slot_start: a.slot_start,
          slot_end: a.slot_end,
          status: a.status,
          student_type: student ? student.student_type : 'Civil' // Garante o tipo real (Civil/Militar) vindo do cadastro do aluno
        };
      });

    return Response.json({ success: true, data: ativos });

  } catch (error) {
    return new Response(`Erro no Deno: ${error.message}`, { status: 500 });
  }
});