import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';
import * as XLSX from 'npm:xlsx@0.18.5';

const maskCPF = (v) => {
  const n = String(v).replace(/\D/g, '').padStart(11, '0').slice(0, 11);
  return `${n.slice(0,3)}.${n.slice(3,6)}.${n.slice(6,9)}-${n.slice(9)}`;
};

const toTitleCase = (str) => {
  const lower = ['da', 'de', 'do', 'das', 'dos', 'e'];
  return str.trim().split(/\s+/).map((w, i) => {
    const wl = w.toLowerCase();
    return (i > 0 && lower.includes(wl)) ? wl : wl.charAt(0).toUpperCase() + wl.slice(1);
  }).join(' ');
};

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);
  const user = await base44.auth.me();
  if (user?.role !== 'admin') {
    return Response.json({ error: 'Forbidden' }, { status: 403 });
  }

  const body = await req.json().catch(() => ({}));
  const fileUrl = body.fileUrl;
  if (!fileUrl) return Response.json({ error: 'fileUrl required' }, { status: 400 });

  const response = await fetch(fileUrl);
  const arrayBuffer = await response.arrayBuffer();
  const workbook = XLSX.read(new Uint8Array(arrayBuffer), { type: 'array' });
  const sheet = workbook.Sheets[workbook.SheetNames[0]];
  const rows = XLSX.utils.sheet_to_json(sheet);

  const batchSize = body.batchSize || 30;
  const offset = body.offset || 0;
  const batch = rows.slice(offset, offset + batchSize);

  let created = 0;
  for (const row of batch) {
    const fullName = toTitleCase(String(row['NOME COMPLETO'] || ''));
    const cpf = maskCPF(row['CPF'] || '');
    const email = String(row['E-mail'] || row['Endereço de e-mail'] || '').trim().toLowerCase();
    const phone = String(row['Telefone'] || '').replace(/\D/g, '');

    if (!fullName || !cpf) continue;

    await base44.asServiceRole.entities.Student.create({
      full_name: fullName,
      cpf,
      email,
      phone,
      student_type: 'Civil',
      active: true,
    });
    created++;
  }

  const remaining = rows.length - offset - batch.length;
  return Response.json({ success: true, created, total: rows.length, remaining, nextOffset: offset + batch.length });
});