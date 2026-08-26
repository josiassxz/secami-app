import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);

  const body = await req.json();

  // Suporte a payload_too_large: busca o aluno pelo entity_id
  let photo_url, cpf;

  if (body?.event?.entity_id) {
    const student = await base44.asServiceRole.entities.Student.get(body.event.entity_id);
    photo_url = student?.photo_url;
    cpf = student?.cpf;
  } else {
    const studentData = body?.data || body;
    photo_url = studentData?.photo_url;
    cpf = studentData?.cpf;
  }

  if (!photo_url || !cpf) {
    return Response.json({ success: false, error: "photo_url e cpf são obrigatórios" }, { status: 400 });
  }

  // Baixa a imagem da URL e converte para base64
  const imageResponse = await fetch(photo_url);
  if (!imageResponse.ok) {
    return Response.json({ success: false, error: "Falha ao baixar a imagem" }, { status: 500 });
  }

  const imageBuffer = await imageResponse.arrayBuffer();
  const bytes = new Uint8Array(imageBuffer);
  let binary = '';
  const chunkSize = 8192;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  const base64 = btoa(binary);

  // Envia para o servidor local via ngrok
  const response = await fetch("https://unchloridized-unsortable-tonda.ngrok-free.dev/cadastroFoto", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ cpf, foto_base64: base64 }),
  });

  const responseText = await response.text();

  return Response.json({
    success: response.ok,
    status: response.status,
    response: responseText,
  });
});