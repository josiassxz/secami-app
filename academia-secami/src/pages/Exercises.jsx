import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Dumbbell, Plus, Search, X, Edit, Trash2, Video, Camera, Loader2, Eye } from 'lucide-react';

const MUSCLE_GROUPS = ['Peito', 'Costas', 'Ombros', 'Bíceps', 'Tríceps', 'Abdômen', 'Quadríceps', 'Posterior', 'Glúteos', 'Panturrilha', 'Cardio', 'Funcional'];

export default function Exercises() {
  const { user } = useAuth();
  const role = user?.role;
  const [exercises, setExercises] = useState([]);
  const [search, setSearch] = useState('');
  const [filterGroup, setFilterGroup] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [form, setForm] = useState({ name: '', muscle_group: '', description: '', equipment: '', video_url: '', photo_url: '' });
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);

  const canEdit = ['admin', 'professor'].includes(role);
  const [viewExercise, setViewExercise] = useState(null);

  const load = async () => {
    const data = await base44.entities.Exercise.list('-created_date', 200);
    setExercises(data);
  };

  useEffect(() => { load(); }, []);

  const handlePhotoUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const { file_url } = await base44.integrations.Core.UploadFile({ file });
    setForm(f => ({ ...f, photo_url: file_url }));
    setUploading(false);
  };

  const openForm = (ex = null) => {
    setEditing(ex);
    setForm(ex ? { name: ex.name, muscle_group: ex.muscle_group, description: ex.description || '', equipment: ex.equipment || '', video_url: ex.video_url || '', photo_url: ex.photo_url || '' } : { name: '', muscle_group: '', description: '', equipment: '', video_url: '', photo_url: '' });
    setShowForm(true);
  };

  const handleSave = async () => {
    if (!form.name || !form.muscle_group) return;
    setSaving(true);
    if (editing) {
      await base44.entities.Exercise.update(editing.id, form);
    } else {
      await base44.entities.Exercise.create(form);
    }
    setSaving(false);
    setShowForm(false);
    load();
  };

  const handleDelete = async (id) => {
    if (!confirm('Excluir exercício?')) return;
    await base44.entities.Exercise.delete(id);
    load();
  };

  const filtered = exercises.filter(e =>
    (!filterGroup || e.muscle_group === filterGroup) &&
    e.name?.toLowerCase().includes(search.toLowerCase())
  );

  const inputCls = "w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring";

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">Biblioteca de Exercícios</h1>
        {canEdit && (
          <button onClick={() => openForm()} className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors">
            <Plus className="w-4 h-4" /> Novo
          </button>
        )}
      </div>

      <div className="flex gap-2">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Buscar exercício..." className="w-full bg-card border border-border rounded-lg pl-10 pr-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring" />
        </div>
        <select value={filterGroup} onChange={e => setFilterGroup(e.target.value)} className="bg-card border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none">
          <option value="">Todos</option>
          {MUSCLE_GROUPS.map(g => <option key={g} value={g}>{g}</option>)}
        </select>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        {filtered.map(ex => (
          <div key={ex.id} className="bg-card border border-border rounded-xl overflow-hidden hover:border-primary/40 transition-colors group cursor-pointer" onClick={() => setViewExercise(ex)}>
            {ex.photo_url && (
              <img src={ex.photo_url} alt={ex.name} className="w-full object-contain bg-muted/20" style={{maxHeight: '160px'}} />
            )}
            <div className="p-4">
              <div className="flex items-start justify-between mb-2">
                <div>
                  <p className="font-semibold text-foreground text-sm">{ex.name}</p>
                  <span className="text-xs px-2 py-0.5 rounded-full bg-primary/20 text-primary mt-1 inline-block">{ex.muscle_group}</span>
                </div>
                <div className="flex gap-1">
                  {canEdit && (
                    <>
                      <button onClick={e => { e.stopPropagation(); openForm(ex); }} className="p-1 text-muted-foreground hover:text-primary opacity-0 group-hover:opacity-100 transition-opacity"><Edit className="w-3.5 h-3.5" /></button>
                      <button onClick={e => { e.stopPropagation(); handleDelete(ex.id); }} className="p-1 text-muted-foreground hover:text-destructive opacity-0 group-hover:opacity-100 transition-opacity"><Trash2 className="w-3.5 h-3.5" /></button>
                    </>
                  )}
                </div>
              </div>
              {ex.description && <p className="text-xs text-muted-foreground line-clamp-2">{ex.description}</p>}
              {ex.equipment && <p className="text-xs text-muted-foreground mt-1">🏋️ {ex.equipment}</p>}
            </div>
          </div>
        ))}
        {filtered.length === 0 && (
          <div className="col-span-full text-center py-12">
            <Dumbbell className="w-10 h-10 mx-auto mb-3 text-muted-foreground opacity-30" />
            <p className="text-muted-foreground">Nenhum exercício encontrado</p>
          </div>
        )}
      </div>

      {viewExercise && (
        <div className="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-md overflow-hidden max-h-[90vh] flex flex-col">
            {viewExercise.photo_url && (
              <img src={viewExercise.photo_url} alt={viewExercise.name} className="w-full object-contain bg-muted/20 flex-shrink-0 max-h-72" />
            )}
            <div className="p-5 space-y-3 overflow-y-auto">
              <div className="flex items-start justify-between">
                <div>
                  <p className="font-bold text-lg text-foreground">{viewExercise.name}</p>
                  {viewExercise.muscle_group && <span className="text-xs px-2 py-0.5 rounded-full bg-primary/20 text-primary mt-1 inline-block">{viewExercise.muscle_group}</span>}
                </div>
                <button onClick={() => setViewExercise(null)} className="p-1.5 text-muted-foreground hover:text-foreground"><X className="w-5 h-5" /></button>
              </div>
              {viewExercise.equipment && <p className="text-sm text-muted-foreground">🏋️ <span className="text-foreground">{viewExercise.equipment}</span></p>}
              {viewExercise.description && <p className="text-sm text-muted-foreground leading-relaxed">{viewExercise.description}</p>}
              {viewExercise.video_url && (
                <a href={viewExercise.video_url} target="_blank" rel="noopener noreferrer"
                  className="flex items-center gap-2 bg-primary/10 border border-primary/20 text-primary rounded-lg px-4 py-2.5 text-sm font-medium hover:bg-primary/20 transition-colors">
                  <Video className="w-4 h-4" /> Ver vídeo demonstrativo
                </a>
              )}
              <button onClick={() => setViewExercise(null)} className="w-full py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Fechar</button>
            </div>
          </div>
        </div>
      )}

      {showForm && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-sm">
            <div className="flex items-center justify-between px-5 py-4 border-b border-border">
              <h2 className="font-semibold text-foreground">{editing ? 'Editar Exercício' : 'Novo Exercício'}</h2>
              <button onClick={() => setShowForm(false)}><X className="w-4 h-4 text-muted-foreground" /></button>
            </div>
            <div className="p-5 space-y-3">
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Nome *</label>
                <input className={inputCls} value={form.name} onChange={e => setForm(f => ({ ...f, name: e.target.value }))} />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Grupo Muscular *</label>
                <select className={inputCls} value={form.muscle_group} onChange={e => setForm(f => ({ ...f, muscle_group: e.target.value }))}>
                  <option value="">Selecione...</option>
                  {MUSCLE_GROUPS.map(g => <option key={g} value={g}>{g}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Equipamento</label>
                <input className={inputCls} value={form.equipment} onChange={e => setForm(f => ({ ...f, equipment: e.target.value }))} placeholder="Ex: Halteres, Barra..." />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Foto</label>
                <div className="flex items-center gap-3">
                  {form.photo_url && <img src={form.photo_url} alt="preview" className="w-16 h-16 rounded-lg object-cover border border-border" />}
                  <label className="flex items-center gap-2 cursor-pointer bg-background border border-border rounded-lg px-3 py-2 text-sm text-muted-foreground hover:border-primary/50 transition-colors">
                    {uploading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Camera className="w-4 h-4" />}
                    {uploading ? 'Enviando...' : 'Selecionar foto'}
                    <input type="file" accept="image/*" className="hidden" onChange={handlePhotoUpload} disabled={uploading} />
                  </label>
                </div>
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Link do Vídeo Demonstrativo</label>
                <input className={inputCls} value={form.video_url} onChange={e => setForm(f => ({ ...f, video_url: e.target.value }))} placeholder="https://youtube.com/..." />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Descrição</label>
                <textarea className={inputCls} rows={2} value={form.description} onChange={e => setForm(f => ({ ...f, description: e.target.value }))} />
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