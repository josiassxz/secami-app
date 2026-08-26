import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

const toTitleCase = (str) => {
  if (!str) return str;
  return str
    .toLowerCase()
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
};

Deno.serve(async (req) => {
  const base44 = createClientFromRequest(req);
  const user = await base44.auth.me();
  if (user?.role !== 'admin') {
    return Response.json({ error: 'Forbidden' }, { status: 403 });
  }

  const students = await base44.asServiceRole.entities.Student.list('-created_date', 1000);
  
  let updated = 0;
  for (const s of students) {
    const normalized = toTitleCase(s.full_name);
    if (normalized !== s.full_name) {
      await base44.asServiceRole.entities.Student.update(s.id, { full_name: normalized });
      updated++;
    }
  }

  return Response.json({ success: true, updated });
});