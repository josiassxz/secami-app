import { createClientFromRequest } from 'npm:@base44/sdk@0.8.23';

Deno.serve(async (req) => {
  try {
    const base44 = createClientFromRequest(req);
    const { email, cpf, password } = await req.json();

    let student = null;

    if (email && password) {
      try {
        const user = await base44.auth.login(email, password);
        if (user) {
          const students = await base44.asServiceRole.entities.Student.filter({ user_id: user.id });
          student = students[0];
        }
      } catch (err) {
        return Response.json({ error: 'Email ou senha inválidos' }, { status: 401 });
      }
    } else if (cpf && password) {
      const students = await base44.asServiceRole.entities.Student.filter({ cpf });
      if (students.length === 0) {
        return Response.json({ error: 'CPF ou senha inválidos' }, { status: 401 });
      }
      student = students[0];
      if (student.password !== password) {
        return Response.json({ error: 'CPF ou senha inválidos' }, { status: 401 });
      }
    } else {
      return Response.json({ error: 'Credenciais inválidas' }, { status: 400 });
    }

    if (!student) {
      return Response.json({ error: 'Aluno não encontrado' }, { status: 401 });
    }

    return Response.json({ 
      success: true, 
      student_id: student.id,
      student_name: student.full_name,
      student_type: student.student_type,
      user_id: student.user_id
    });
  } catch (error) {
    return Response.json({ error: error.message }, { status: 500 });
  }
});