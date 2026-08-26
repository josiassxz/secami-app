import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Plus, Pencil, Trash2, Building2, X, Check } from 'lucide-react';

export default function Departments() {
  const { user } = useAuth();
  const [departments, setDepartments] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [name, setName] = useState('');
  const [sigla, setSigla] = useState('');
  const [andar, setAndar] = useState('');
  const [saving, setSaving] = useState(false);

  const canEdit = ['admin', 'gerente'].includes(user?.role);

  const load = async () => {
    setLoading(true);
    const data = await base44.entities.Department.list('name', 200);
    setDepartments(data);
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const openForm = (dep = null) => {
    setEditing(dep);
    setName(dep?.name || '');
    setSigla(dep?.sigla || '');
    setAndar(dep?.andar || '');
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!name.trim()) return;
    setSaving(true);
    if (editing) {
      await base44.entities.Department.update(editing.id, { name: name.trim(), sigla: sigla.trim(), andar: andar.trim() });
    } else {
      await base44.entities.Department.create({ name: name.trim(), sigla: sigla.trim(), andar: andar.trim(), active: true });
    }
    setSaving(false);
    setShowForm(false);
    load();
  };

  const handleDelete = async (id) => {
    if (!confirm('Excluir secretaria/órgão?')) return;
    await base44.entities.Department.delete(id);
    load();
  };

  const inputCls = "w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring";

  return (
    <div className="space-y-5 max-w-2xl mx-auto">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Secretarias / Órgãos</h1>
          <p className="text-sm text-muted-foreground mt-0.5">Gerencie as secretarias e órgãos dos alunos</p>
        </div>
        {canEdit && (
          <button
            onClick={() => openForm()}
            className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Plus className="w-4 h-4" /> Nova
          </button>
        )}
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : departments.length === 0 ? (
        <div className="text-center py-16 bg-card border border-border rounded-xl">
          <Building2 className="w-10 h-10 mx-auto mb-3 text-muted-foreground opacity-30" />
          <p className="text-muted-foreground">Nenhuma secretaria cadastrada</p>
        </div>
      ) : (
        <div className="bg-card border border-border rounded-xl overflow-hidden">
          {departments.map((dep, i) => (
            <div key={dep.id} className={`flex items-center justify-between px-5 py-3.5 ${i > 0 ? 'border-t border-border' : ''} group`}>
              <div className="flex items-center gap-3">
                <Building2 className="w-4 h-4 text-muted-foreground flex-shrink-0" />
                <div>
                  <span className="text-sm text-foreground font-medium">{dep.sigla ? `${dep.sigla} - ${dep.name}` : dep.name}</span>
                  <div className="flex gap-2 mt-0.5">
                    {dep.sigla && <span className="text-xs text-muted-foreground">Sigla: <span className="text-foreground">{dep.sigla}</span></span>}
                    {dep.andar && <span className="text-xs text-muted-foreground">Andar: <span className="text-foreground">{dep.andar}</span></span>}
                  </div>
                </div>
              </div>
              {canEdit && (
                <div className="flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                  <button onClick={() => openForm(dep)} className="p-1.5 text-muted-foreground hover:text-primary rounded-lg hover:bg-primary/10 transition-colors">
                    <Pencil className="w-3.5 h-3.5" />
                  </button>
                  <button onClick={() => handleDelete(dep.id)} className="p-1.5 text-muted-foreground hover:text-destructive rounded-lg hover:bg-destructive/10 transition-colors">
                    <Trash2 className="w-3.5 h-3.5" />
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {showForm && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-sm">
            <div className="flex items-center justify-between px-5 py-4 border-b border-border">
              <h2 className="font-semibold text-foreground">{editing ? 'Editar' : 'Nova Secretaria / Órgão'}</h2>
              <button onClick={() => setShowForm(false)}><X className="w-4 h-4 text-muted-foreground" /></button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Nome *</label>
                <input
                  className={inputCls}
                  value={name}
                  onChange={e => setName(e.target.value)}
                  autoFocus
                  placeholder="Ex: Secretaria de Educação"
                />
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs text-muted-foreground mb-1">Sigla</label>
                  <input
                    className={inputCls}
                    value={sigla}
                    onChange={e => setSigla(e.target.value)}
                    placeholder="Ex: SEDUC"
                  />
                </div>
                <div>
                  <label className="block text-xs text-muted-foreground mb-1">Andar</label>
                  <input
                    className={inputCls}
                    value={andar}
                    onChange={e => setAndar(e.target.value)}
                    placeholder="Ex: 3º"
                  />
                </div>
              </div>
              <div className="flex gap-3">
                <button onClick={() => setShowForm(false)} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Cancelar</button>
                <button onClick={handleSave} disabled={saving || !name.trim()} className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50">
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