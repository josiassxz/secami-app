import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);
  const user = await base44.auth.me();
  if (user?.role !== 'admin') {
    return Response.json({ error: 'Forbidden' }, { status: 403 });
  }

  // Fetch all students
  const students = await base44.asServiceRole.entities.Student.list('-created_date', 2000);

  // Group by CPF
  const byCpf = {};
  for (const s of students) {
    const cpf = s.cpf?.replace(/\D/g, '');
    if (!cpf) continue;
    if (!byCpf[cpf]) byCpf[cpf] = [];
    byCpf[cpf].push(s);
  }

  // Find duplicates — keep the first (oldest) one, delete the rest
  const toDelete = [];
  for (const [cpf, list] of Object.entries(byCpf)) {
    if (list.length > 1) {
      // Sort by created_date ascending — keep the oldest
      list.sort((a, b) => new Date(a.created_date) - new Date(b.created_date));
      // Delete all but the first
      for (let i = 1; i < list.length; i++) {
        toDelete.push(list[i].id);
      }
    }
  }

  // Delete duplicates in batches
  let deleted = 0;
  for (const id of toDelete) {
    await base44.asServiceRole.entities.Student.delete(id);
    deleted++;
  }

  return Response.json({ success: true, deleted, total: students.length, remaining: students.length - deleted });
});