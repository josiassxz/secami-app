import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);
  const user = await base44.auth.me();
  if (user?.role !== 'admin') {
    return Response.json({ error: 'Forbidden' }, { status: 403 });
  }

  const body = await req.json().catch(() => ({}));
  const batchSize = body.batchSize || 50;
  const offset = body.offset || 0;

  const students = await base44.asServiceRole.entities.Student.list('-created_date', 1000);

  // Alunos importados têm ID começando com 69cab183
  const toDelete = students.filter(s => s.id.startsWith('69cab183')).slice(offset, offset + batchSize);

  let deleted = 0;
  for (const s of toDelete) {
    await base44.asServiceRole.entities.Student.delete(s.id);
    deleted++;
  }

  const remaining = students.filter(s => s.id.startsWith('69cab183')).length - offset - deleted;

  return Response.json({ success: true, deleted, remaining });
});