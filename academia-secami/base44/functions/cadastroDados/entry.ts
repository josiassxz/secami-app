import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);

  const body = await req.json();

  // Payload can come from automation (entity event) or direct call
  const studentData = body?.data || body;

  // Envia apenas os campos necessários para o servidor externo
  const dataToSend = {
    full_name: studentData.full_name,
    email: studentData.email,
    phone: studentData.phone,
    cpf: studentData.cpf,
    matricula: studentData.matricula,
    birth_date: studentData.birth_date,
  };

  const response = await fetch("https://unchloridized-unsortable-tonda.ngrok-free.dev/cadastroDados", {
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