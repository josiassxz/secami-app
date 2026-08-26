import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Plus, X, Edit, Trash2, Bell, Mail } from 'lucide-react';

export default function Notices() {
  const { user } = useAuth();
  const [notices, setNotices] = useState([]);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState({ title: '', content: '', type: 'info', active: true, target_roles: ['aluno'] });

  const ALL_ROLES = [
    { value: 'aluno', label: 'Aluno' },
    { value: 'professor', label: 'Professor' },
    { value: 'recepcao', label: 'Recepção' },
    { value: 'gerente', label: 'Gerente' },
    { value: 'admin', label: 'Admin' },
  ];

  const toggleRole = (role) => {
    setForm(f => ({
      ...f,
      target_roles: f.target_roles.includes(role)
        ? f.target_roles.filter(r => r !== role)
        : [...f.target_roles, role]
    }));
  };
  const [saving, setSaving] = useState(false);
  const [showEmailModal, setShowEmailModal] = useState(false);
  const [emailForm, setEmailForm] = useState({ subject: '', body: '' });
  const [sendingEmail, setSendingEmail] = useState(false);
  const [emailResult, setEmailResult] = useState(null);

  const canEdit = ['admin', 'gerente'].includes(user?.role);

  const load = async () => {
    const data = await base44.entities.Notice.list('-created_date', 50);
    setNotices(data);
  };

  useEffect(() => { load(); }, []);

  const openNew = () => {
    setEditing(null);
    setForm({ title: '', content: '', type: 'info', active: true, target_roles: ['aluno'] });
    setShowForm(true);
  };

  const openEdit = (n) => {
    setEditing(n);
    setForm({ title: n.title, content: n.content, type: n.type || 'info', active: n.active, target_roles: n.target_roles || ['aluno'] });
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!form.title || !form.content) return;
    setSaving(true);
    if (editing) {
      await base44.entities.Notice.update(editing.id, form);
    } else {
      await base44.entities.Notice.create(form);
    }
    setSaving(false);
    setShowForm(false);
    load();
  };

  const handleSendEmail = async () => {
    if (!emailForm.subject || !emailForm.body) return;
    setSendingEmail(true);
    setEmailResult(null);
    const res = await base44.functions.invoke('sendEmailsToStudents', emailForm);
    setEmailResult(res.data);
    setSendingEmail(false);
    if (res.data?.success) {
      setEmailForm({ subject: '', body: '' });
    }
  };

  const handleDelete = async (id) => {
    if (!confirm('Excluir este informativo?')) return;
    await base44.entities.Notice.delete(id);
    load();
  };

  const ROLE_LABEL = { aluno: 'Aluno', professor: 'Professor', recepcao: 'Recepção', gerente: 'Gerente', admin: 'Admin' };
  const typeLabel = { info: 'Informativo', warning: 'Atenção', success: 'Destaque' };
  const typeColor = {
    info: 'bg-blue-500/20 text-blue-400',
    warning: 'bg-yellow-500/20 text-yellow-400',
    success: 'bg-primary/20 text-primary',
  };

  const inputCls = "w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring";

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Informativos</h1>
          <p className="text-muted-foreground text-sm">Mensagens exibidas no dashboard dos alunos</p>
        </div>
        {canEdit && (
          <div className="flex items-center gap-2">
            <button onClick={() => { setShowEmailModal(true); setEmailResult(null); }} className="flex items-center gap-2 bg-secondary text-secondary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-secondary/80 border border-border">
              <Mail className="w-4 h-4" /> Enviar E-mail
            </button>
            <button onClick={openNew} className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90">
              <Plus className="w-4 h-4" /> Novo Informativo
            </button>
          </div>
        )}
      </div>

      <div className="space-y-3">
        {notices.length === 0 ? (
          <div className="text-center py-12 text-muted-foreground">
            <Bell className="w-10 h-10 mx-auto mb-3 opacity-30" />
            <p>Nenhum informativo cadastrado</p>
          </div>
        ) : (
          notices.map(n => (
            <div key={n.id} className={`bg-card border border-border rounded-xl p-5 ${!n.active ? 'opacity-50' : ''}`}>
              <div className="flex items-start justify-between gap-3">
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 mb-1">
                    <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${typeColor[n.type] || typeColor.info}`}>
                      {typeLabel[n.type] || 'Informativo'}
                    </span>
                    {!n.active && <span className="text-xs px-2 py-0.5 rounded-full bg-muted text-muted-foreground">Inativo</span>}
                  </div>
                  <p className="font-semibold text-foreground">{n.title}</p>
                  <p className="text-sm text-muted-foreground mt-1">{n.content}</p>
                  {n.target_roles?.length > 0 && (
                    <div className="flex flex-wrap gap-1 mt-2">
                      {n.target_roles.map(r => (
                        <span key={r} className="text-[10px] px-1.5 py-0.5 rounded bg-muted text-muted-foreground">{ROLE_LABEL[r] || r}</span>
                      ))}
                    </div>
                  )}
                  </div>
                {canEdit && (
                  <div className="flex items-center gap-1 flex-shrink-0">
                    <button onClick={() => openEdit(n)} className="p-1.5 rounded-lg text-muted-foreground hover:text-primary hover:bg-primary/10">
                      <Edit className="w-4 h-4" />
                    </button>
                    <button onClick={() => handleDelete(n.id)} className="p-1.5 rounded-lg text-muted-foreground hover:text-destructive hover:bg-destructive/10">
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                )}
              </div>
            </div>
          ))
        )}
      </div>

      {showEmailModal && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-md">
            <div className="flex items-center justify-between px-6 py-4 border-b border-border">
              <h2 className="font-semibold text-foreground flex items-center gap-2"><Mail className="w-4 h-4 text-primary" /> Enviar E-mail para Alunos</h2>
              <button onClick={() => setShowEmailModal(false)}><X className="w-5 h-5 text-muted-foreground" /></button>
            </div>
            <div className="p-6 space-y-4">
              <p className="text-xs text-muted-foreground">O e-mail será enviado para todos os alunos ativos que possuem endereço de e-mail cadastrado.</p>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Assunto *</label>
                <input className={inputCls} value={emailForm.subject} onChange={e => setEmailForm(f => ({ ...f, subject: e.target.value }))} placeholder="Ex: Aviso importante sobre a academia" />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Mensagem *</label>
                <textarea className={`${inputCls} resize-none`} rows={5} value={emailForm.body} onChange={e => setEmailForm(f => ({ ...f, body: e.target.value }))} placeholder="Escreva a mensagem que será enviada para os alunos..." />
              </div>
              {emailResult && (
                <div className={`rounded-lg px-4 py-3 text-sm ${emailResult.success ? 'bg-primary/10 text-primary border border-primary/20' : 'bg-destructive/10 text-destructive border border-destructive/20'}`}>
                  {emailResult.success ? `✓ E-mail enviado com sucesso para ${emailResult.sentCount} aluno(s)!` : `Erro: ${emailResult.error}`}
                </div>
              )}
              <div className="flex gap-3 pt-1">
                <button onClick={() => setShowEmailModal(false)} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Fechar</button>
                <button onClick={handleSendEmail} disabled={sendingEmail || !emailForm.subject || !emailForm.body} className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50">
                  {sendingEmail ? 'Enviando...' : 'Enviar E-mail'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {showForm && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-md">
            <div className="flex items-center justify-between px-6 py-4 border-b border-border">
              <h2 className="font-semibold text-foreground">{editing ? 'Editar Informativo' : 'Novo Informativo'}</h2>
              <button onClick={() => setShowForm(false)}><X className="w-5 h-5 text-muted-foreground" /></button>
            </div>
            <div className="p-6 space-y-4">
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Título *</label>
                <input className={inputCls} value={form.title} onChange={e => setForm(f => ({ ...f, title: e.target.value }))} placeholder="Ex: Feriado na próxima segunda" />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Conteúdo *</label>
                <textarea className={`${inputCls} resize-none`} rows={4} value={form.content} onChange={e => setForm(f => ({ ...f, content: e.target.value }))} placeholder="Descreva o informativo..." />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Tipo</label>
                <select className={inputCls} value={form.type} onChange={e => setForm(f => ({ ...f, type: e.target.value }))}>
                  <option value="info">Informativo</option>
                  <option value="warning">Atenção</option>
                  <option value="success">Destaque</option>
                </select>
              </div>
               <div>
                <label className="block text-xs text-muted-foreground mb-2">Perfis que verão este informativo</label>
                <div className="flex flex-wrap gap-2">
                  {ALL_ROLES.map(r => (
                    <button
                      key={r.value}
                      type="button"
                      onClick={() => toggleRole(r.value)}
                      className={`px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors ${
                        form.target_roles.includes(r.value)
                          ? 'bg-primary text-primary-foreground border-primary'
                          : 'bg-background border-border text-muted-foreground hover:border-primary/50'
                      }`}
                    >
                      {r.label}
                    </button>
                  ))}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <input type="checkbox" id="active" checked={form.active} onChange={e => setForm(f => ({ ...f, active: e.target.checked }))} className="accent-primary" />
                <label htmlFor="active" className="text-sm text-foreground">Ativo</label>
              </div>
              <div className="flex gap-3 pt-1">
                <button onClick={() => setShowForm(false)} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Cancelar</button>
                <button onClick={handleSave} disabled={saving} className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50">
                  {saving ? 'Salvando...' : 'Salvar'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}