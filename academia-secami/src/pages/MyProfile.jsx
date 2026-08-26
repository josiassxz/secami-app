import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Edit, Camera, Loader2, User } from 'lucide-react';
import { parseISO, addYears, format } from 'date-fns';

export default function MyProfile() {
  const { user } = useAuth();
  const [student, setStudent] = useState(null);
  const [loading, setLoading] = useState(true);
  const [editing, setEditing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [form, setForm] = useState({});

  const maskCPF = (cpf) => {
    if (!cpf) return '–';
    const digits = cpf.replace(/\D/g, '');
    if (digits.length !== 11) return cpf;
    return `${digits.slice(0,3)}.***.***-${digits.slice(9)}`;
  };

  const load = async () => {
    setLoading(true);
    const session = JSON.parse(localStorage.getItem('studentSession') || 'null');
    let s = null;
    if (session?.student_id) {
      const studs = await base44.entities.Student.filter({ id: session.student_id });
      s = studs[0] || null;
    } else if (user?.id) {
      const mine = await base44.entities.Student.filter({ user_id: user.id });
      s = mine[0] || null;
    }
    setStudent(s);
    if (s) {
      setForm({ weight: s.weight || '', height: s.height || '', phone: s.phone || '', photo_url: s.photo_url || '', goal: s.goal || '' });
    }
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const handlePhotoChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const { file_url } = await base44.integrations.Core.UploadFile({ file });
    setForm(f => ({ ...f, photo_url: file_url }));
    setUploading(false);
  };

  const handleSave = async () => {
    setSaving(true);
    const data = {};
    if (form.weight) data.weight = parseFloat(form.weight);
    if (form.height) data.height = parseFloat(form.height);
    if (form.phone) data.phone = form.phone;
    data.photo_url = form.photo_url || '';
    data.goal = form.goal;
    await base44.entities.Student.update(student.id, data);
    setSaving(false);
    setEditing(false);
    await load();
  };

  const inputCls = "w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring";

  if (loading) return (
    <div className="flex justify-center py-20">
      <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
    </div>
  );

  if (!student) return (
    <div className="text-center py-20 text-muted-foreground">
      <User className="w-12 h-12 mx-auto mb-3 opacity-30" />
      <p>Perfil não configurado. Fale com a recepção.</p>
    </div>
  );



  return (
    <div className="max-w-md mx-auto space-y-5">
      {uploading && (
        <div className="fixed inset-0 bg-black/60 z-[9999] flex flex-col items-center justify-center gap-3">
          <Loader2 className="w-10 h-10 animate-spin text-primary" />
          <p className="text-sm text-white font-medium">Enviando foto, aguarde...</p>
        </div>
      )}
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">Meu Perfil</h1>
        <div className="flex items-center gap-2">
          {!editing && (
            <button onClick={() => setEditing(true)} className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90">
              <Edit className="w-4 h-4" /> Editar
            </button>
          )}
        </div>
      </div>

      <div className="bg-card border border-border rounded-xl p-6 space-y-5">
        {/* Foto */}
        <div className="flex flex-col items-center gap-3">
          <div className="relative w-24 h-24">
            <label className={editing ? 'cursor-pointer' : 'cursor-default'}>
              {(editing ? form.photo_url : student.photo_url) ? (
                <img src={editing ? form.photo_url : student.photo_url} alt="foto" className="w-24 h-24 rounded-full object-cover border-2 border-primary" />
              ) : (
                <div className="w-24 h-24 rounded-full bg-primary/20 flex items-center justify-center text-primary text-3xl font-bold border-2 border-primary/40">
                  {student.full_name?.[0]?.toUpperCase()}
                </div>
              )}
              {editing && <input type="file" accept="image/*" className="hidden" onChange={handlePhotoChange} disabled={uploading} />}
            </label>
            {editing && (
              <label className="absolute bottom-0 right-0 bg-primary text-primary-foreground rounded-full p-1.5 cursor-pointer hover:bg-primary/90 pointer-events-none">
                {uploading ? <Loader2 className="w-3 h-3 animate-spin" /> : <Camera className="w-3 h-3" />}
              </label>
            )}
          </div>
          <div className="text-center">
            <p className="font-semibold text-foreground">{student.full_name}</p>
            <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${student.student_type === 'Civil' ? 'bg-blue-500/20 text-blue-400' : 'bg-orange-500/20 text-orange-400'}`}>
              {student.student_type}
            </span>
          </div>
        </div>

        {/* Info fixa */}
        <div className="grid grid-cols-2 gap-3 text-sm">
          <div className="bg-muted/30 rounded-lg p-3">
            <p className="text-xs text-muted-foreground mb-0.5">CPF</p>
            <p className="text-foreground font-medium">{maskCPF(student.cpf)}</p>
          </div>
          <div className="bg-muted/30 rounded-lg p-3">
            <p className="text-xs text-muted-foreground mb-0.5">Objetivo</p>
            <p className="text-foreground font-medium">{student.goal}</p>
          </div>
        </div>

        {/* Campos editáveis */}
        {editing ? (
          <div className="space-y-3">
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Peso (kg)</label>
                <input type="number" className={inputCls} value={form.weight} onChange={e => setForm(f => ({ ...f, weight: e.target.value }))} placeholder="Ex: 75" />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Altura (cm)</label>
                <input type="number" className={inputCls} value={form.height} onChange={e => setForm(f => ({ ...f, height: e.target.value }))} placeholder="Ex: 175" />
              </div>
            </div>
            <div>
              <label className="block text-xs text-muted-foreground mb-1">Telefone</label>
              <input type="tel" className={inputCls} value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} placeholder="(00) 00000-0000" />
            </div>
            <div>
              <label className="block text-xs text-muted-foreground mb-1">Objetivo</label>
              <select
                className="w-full border border-border rounded-lg px-3 py-2 text-sm text-foreground bg-card focus:outline-none focus:ring-2 focus:ring-ring"
                value={form.goal}
                onChange={e => setForm(f => ({ ...f, goal: e.target.value }))}
              >
                <option value="">Selecione...</option>
                {['Emagrecimento', 'Hipertrofia', 'Condicionamento', 'Saúde e Bem-estar', 'Reabilitação', 'Força'].map(g => (
                  <option key={g} value={g}>{g}</option>
                ))}
              </select>
            </div>
            <div className="flex gap-3 pt-1">
              <button onClick={() => setEditing(false)} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Cancelar</button>
              <button onClick={handleSave} disabled={saving || uploading} className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50">
                {saving ? 'Salvando...' : 'Salvar'}
              </button>
            </div>
          </div>
        ) : (
          <div className="grid grid-cols-2 gap-3 text-sm">
            <div className="bg-muted/30 rounded-lg p-3">
              <p className="text-xs text-muted-foreground mb-0.5">Peso</p>
              <p className="text-foreground font-medium">{student.weight ? `${student.weight} kg` : '–'}</p>
            </div>
            <div className="bg-muted/30 rounded-lg p-3">
              <p className="text-xs text-muted-foreground mb-0.5">Altura</p>
              <p className="text-foreground font-medium">{student.height ? `${student.height} cm` : '–'}</p>
            </div>
            <div className="bg-muted/30 rounded-lg p-3 col-span-2">
              <p className="text-xs text-muted-foreground mb-0.5">Telefone</p>
              <p className="text-foreground font-medium">{student.phone || '–'}</p>
            </div>
            <div className="bg-muted/30 rounded-lg p-3 col-span-2">
              <p className="text-xs text-muted-foreground mb-0.5">Atestado Médico</p>
              <p className="text-foreground font-medium text-sm">
                {student.atestado_data
                  ? new Date(student.atestado_data + 'T12:00:00').toLocaleDateString('pt-BR')
                  : '–'}
                {student.atestado_numero ? ` · Nº ${student.atestado_numero}` : ''}
              </p>
            </div>
            <div className="bg-muted/30 rounded-lg p-3 col-span-2">
              <p className="text-xs text-muted-foreground mb-0.5">Conta Vinculada</p>
              {student.user_id ? (
                <p className="text-foreground font-medium text-sm">{user?.full_name} <span className="text-muted-foreground font-normal">({user?.email})</span></p>
              ) : (
                <p className="text-muted-foreground text-sm">Nenhuma conta vinculada. Fale com a recepção.</p>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}