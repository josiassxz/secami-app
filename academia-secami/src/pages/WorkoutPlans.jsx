import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { ClipboardList, Plus, X, ChevronDown, ChevronUp, Trash2, Pencil } from 'lucide-react';

export default function WorkoutPlans() {
  const { user } = useAuth();
  const role = user?.role;
  const [plans, setPlans] = useState([]);
  const [students, setStudents] = useState([]);
  const [exercises, setExercises] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [expanded, setExpanded] = useState(null);
  const [filterStudent, setFilterStudent] = useState('');
  const [form, setForm] = useState({ student_id: '', sheet_label: 'A', title: '', exercises: [] });
  const [saving, setSaving] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [studentSearch, setStudentSearch] = useState('');
  const [showStudentDropdown, setShowStudentDropdown] = useState(false);

  const canEdit = ['admin', 'professor'].includes(role);

  const load = async () => {
    const [p, s, e] = await Promise.all([
      base44.entities.WorkoutPlan.list('-created_date', 200),
      base44.entities.Student.list(),
      base44.entities.Exercise.list(),
    ]);
    setPlans(p);
    setStudents(s);
    setExercises(e);
  };

  useEffect(() => { load(); }, []);

  const addExercise = () => {
    setForm(f => ({ ...f, exercises: [...f.exercises, { exercise_id: '', exercise_name: '', sets: 3, reps: '12', rest_seconds: 60, notes: '' }] }));
  };

  const updateExercise = (idx, field, value) => {
    setForm(f => {
      const exs = [...f.exercises];
      exs[idx] = { ...exs[idx], [field]: value };
      if (field === 'exercise_id') {
        const ex = exercises.find(e => e.id === value);
        exs[idx].exercise_name = ex?.name || '';
      }
      return { ...f, exercises: exs };
    });
  };

  const removeExercise = (idx) => {
    setForm(f => ({ ...f, exercises: f.exercises.filter((_, i) => i !== idx) }));
  };

  const handleSave = async () => {
    if (!form.student_id || !form.title) return;
    setSaving(true);
    const student = students.find(s => s.id === form.student_id);
    const data = { ...form, student_name: student?.full_name || '', professor_name: user?.full_name || '' };
    if (editingId) {
      await base44.entities.WorkoutPlan.update(editingId, data);
    } else {
      await base44.entities.WorkoutPlan.create(data);
    }
    setSaving(false);
    setShowForm(false);
    setEditingId(null);
    load();
  };

  const handleEdit = (plan) => {
    setForm({
      student_id: plan.student_id,
      sheet_label: plan.sheet_label,
      title: plan.title,
      exercises: plan.exercises || [],
    });
    setEditingId(plan.id);
    setStudentSearch('');
    setShowStudentDropdown(false);
    setShowForm(true);
  };

  const handleDelete = async (id) => {
    if (!confirm('Excluir esta ficha?')) return;
    await base44.entities.WorkoutPlan.delete(id);
    load();
  };

  const filtered = plans.filter(p => !filterStudent || p.student_id === filterStudent);
  const inputCls = "w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring";

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">Fichas de Treino</h1>
        {canEdit && (
          <button onClick={() => { setShowForm(true); setForm({ student_id: '', sheet_label: 'A', title: '', exercises: [] }); setEditingId(null); setStudentSearch(''); setShowStudentDropdown(false); }} className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors">
            <Plus className="w-4 h-4" /> Nova Ficha
          </button>
        )}
      </div>

      <select value={filterStudent} onChange={e => setFilterStudent(e.target.value)} className="bg-card border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none w-full sm:w-72">
        <option value="">Todos os alunos</option>
        {students.map(s => <option key={s.id} value={s.id}>{s.full_name}</option>)}
      </select>

      <div className="space-y-3">
        {filtered.length === 0 && (
          <div className="text-center py-12 text-muted-foreground">
            <ClipboardList className="w-10 h-10 mx-auto mb-3 opacity-30" />
            <p>Nenhuma ficha encontrada</p>
          </div>
        )}
        {filtered.map(plan => (
          <div key={plan.id} className="bg-card border border-border rounded-xl overflow-hidden">
            <div className="flex items-center gap-3 px-5 py-4 cursor-pointer" onClick={() => setExpanded(expanded === plan.id ? null : plan.id)}>
              <span className="w-9 h-9 rounded-xl bg-primary/20 text-primary font-bold flex items-center justify-center flex-shrink-0">{plan.sheet_label}</span>
              <div className="flex-1 min-w-0">
                <p className="font-semibold text-foreground text-sm">{plan.title}</p>
                <p className="text-xs text-muted-foreground">{plan.student_name} · {plan.exercises?.length || 0} exercícios</p>
                {plan.professor_name && <p className="text-xs text-muted-foreground">Prof: {plan.professor_name}</p>}
              </div>
              <div className="flex items-center gap-2">
                {canEdit && (
                  <>
                    <button onClick={e => { e.stopPropagation(); handleEdit(plan); }} className="p-1.5 text-muted-foreground hover:text-primary">
                      <Pencil className="w-4 h-4" />
                    </button>
                    <button onClick={e => { e.stopPropagation(); handleDelete(plan.id); }} className="p-1.5 text-muted-foreground hover:text-destructive">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </>
                )}
                {expanded === plan.id ? <ChevronUp className="w-4 h-4 text-muted-foreground" /> : <ChevronDown className="w-4 h-4 text-muted-foreground" />}
              </div>
            </div>
            {expanded === plan.id && plan.exercises?.length > 0 && (
              <div className="border-t border-border">
                <table className="w-full text-sm">
                  <thead className="bg-muted/30">
                    <tr>
                      <th className="text-left px-5 py-2 text-xs text-muted-foreground">Exercício</th>
                      <th className="text-center px-3 py-2 text-xs text-muted-foreground">Séries</th>
                      <th className="text-center px-3 py-2 text-xs text-muted-foreground">Reps</th>
                      <th className="text-center px-3 py-2 text-xs text-muted-foreground">Descanso</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {plan.exercises.map((ex, i) => (
                      <tr key={i}>
                        <td className="px-5 py-2.5 text-foreground">{ex.exercise_name}</td>
                        <td className="px-3 py-2.5 text-center text-muted-foreground">{ex.sets}x</td>
                        <td className="px-3 py-2.5 text-center text-muted-foreground">{ex.reps}</td>
                        <td className="px-3 py-2.5 text-center text-muted-foreground">{ex.rest_seconds}s</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        ))}
      </div>

      {showForm && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between px-6 py-4 border-b border-border sticky top-0 bg-card z-10">
              <h2 className="font-semibold text-foreground">{editingId ? 'Editar Ficha de Treino' : 'Nova Ficha de Treino'}</h2>
              <button onClick={() => setShowForm(false)}><X className="w-5 h-5 text-muted-foreground" /></button>
            </div>
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-2 gap-3">
                <div className="relative">
                  <label className="block text-xs text-muted-foreground mb-1">Aluno *</label>
                  <input
                    className={inputCls}
                    placeholder="Pesquisar aluno..."
                    value={studentSearch || students.find(s => s.id === form.student_id)?.full_name || ''}
                    onChange={e => { setStudentSearch(e.target.value); setForm(f => ({ ...f, student_id: '' })); setShowStudentDropdown(true); }}
                    onFocus={() => { setStudentSearch(''); setShowStudentDropdown(true); }}
                    onBlur={() => setTimeout(() => setShowStudentDropdown(false), 150)}
                  />
                  {showStudentDropdown && (
                    <div className="absolute z-20 top-full mt-1 w-full bg-card border border-border rounded-lg shadow-lg max-h-48 overflow-y-auto">
                      {students.filter(s => s.full_name?.toLowerCase().includes(studentSearch.toLowerCase())).map(s => (
                        <div
                          key={s.id}
                          className="px-3 py-2 text-sm text-foreground hover:bg-muted/40 cursor-pointer"
                          onMouseDown={() => { setForm(f => ({ ...f, student_id: s.id })); setStudentSearch(''); setShowStudentDropdown(false); }}
                        >
                          {s.full_name}
                        </div>
                      ))}
                      {students.filter(s => s.full_name?.toLowerCase().includes(studentSearch.toLowerCase())).length === 0 && (
                        <div className="px-3 py-2 text-sm text-muted-foreground">Nenhum aluno encontrado</div>
                      )}
                    </div>
                  )}
                </div>
                <div>
                  <label className="block text-xs text-muted-foreground mb-1">Ficha</label>
                  <select className={inputCls} value={form.sheet_label} onChange={e => setForm(f => ({ ...f, sheet_label: e.target.value }))}>
                    {['A', 'B', 'C', 'D'].map(l => <option key={l} value={l}>Ficha {l}</option>)}
                  </select>
                </div>
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Título *</label>
                <input className={inputCls} value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder="Ex: Treino de Peito e Tríceps" />
              </div>

              <div>
                <div className="flex items-center justify-between mb-2">
                  <label className="text-xs text-muted-foreground font-medium">Exercícios</label>
                  <button onClick={addExercise} className="text-xs text-primary flex items-center gap-1 hover:underline">
                    <Plus className="w-3 h-3" /> Adicionar
                  </button>
                </div>
                <div className="space-y-2">
                  {form.exercises.map((ex, i) => (
                    <div key={i} className="bg-background border border-border rounded-lg p-3 space-y-2">
                      <div className="flex gap-2">
                        <select className={`${inputCls} flex-1`} value={ex.exercise_id} onChange={e => updateExercise(i, 'exercise_id', e.target.value)}>
                          <option value="">Exercício...</option>
                          {exercises.map(e => <option key={e.id} value={e.id}>{e.name} ({e.muscle_group})</option>)}
                        </select>
                        <button onClick={() => removeExercise(i)} className="p-2 text-muted-foreground hover:text-destructive"><X className="w-4 h-4" /></button>
                      </div>
                      <div className="grid grid-cols-3 gap-2">
                        <div>
                          <label className="text-xs text-muted-foreground">Séries</label>
                          <input type="number" className={inputCls} value={ex.sets} onChange={e => updateExercise(i, 'sets', parseInt(e.target.value))} />
                        </div>
                        <div>
                          <label className="text-xs text-muted-foreground">Reps</label>
                          <input className={inputCls} value={ex.reps} onChange={e => updateExercise(i, 'reps', e.target.value)} placeholder="12 ou 8-12" />
                        </div>
                        <div>
                          <label className="text-xs text-muted-foreground">Descanso (s)</label>
                          <input type="number" className={inputCls} value={ex.rest_seconds} onChange={e => updateExercise(i, 'rest_seconds', parseInt(e.target.value))} />
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="flex gap-3 pt-2">
                <button onClick={() => { setShowForm(false); setEditingId(null); }} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Cancelar</button>
                <button onClick={handleSave} disabled={saving} className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50">
                  {saving ? 'Salvando...' : editingId ? 'Atualizar Ficha' : 'Salvar Ficha'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}