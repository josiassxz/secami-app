import { createClientFromRequest } from 'npm:@base44/sdk@0.8.25';

Deno.serve(async (req) => {
  try {
    // 1. Valida a chave enviada pela catraca
    const apiKeyRecebida = req.headers.get('x-hardware-api-key') || '';
    const expectedKey = Deno.env.get('HARDWARE_API_KEY');

    if (!apiKeyRecebida || apiKeyRecebida !== expectedKey) {
      return Response.json({ success: false, erro: 'Não autorizado' }, { status: 401 });
    }

    // 2. Inicializa o cliente Base44 a partir da requisição (suporte a asServiceRole)
    const base44 = createClientFromRequest(req);

    // 3. Processa o Giro da Catraca
    const body = await req.json();
    const { cpf, tipo_evento, data_hora_giro } = body;

    if (!cpf || !tipo_evento) {
      return Response.json({ success: false, erro: "CPF e tipo_evento são obrigatórios" }, { status: 400 });
    }

    const cpfNormalizado = cpf.replace(/\D/g, '');

    const allStudents = await base44.asServiceRole.entities.Student.list();
    const student = allStudents.find(s => (s.cpf || '').replace(/\D/g, '') === cpfNormalizado) || null;

    if (!student) {
      return Response.json({ success: false, erro: "Aluno não encontrado na nuvem" }, { status: 404 });
    }

    // Usa o horário do giro da catraca se fornecido, caso contrário usa o horário atual
    const dataHoraFinal = data_hora_giro || new Date().toISOString();

    const novoRegistro = await base44.asServiceRole.entities.Frequencia.create({
      student_id: student.id,
      student_name: student.full_name,
      data_hora: dataHoraFinal,
      tipo: tipo_evento,
    });

    return Response.json({ success: true, registro: novoRegistro });

  } catch (error) {
    return new Response(`Erro no Deno: ${error.message}`, { status: 500 });
  }
});