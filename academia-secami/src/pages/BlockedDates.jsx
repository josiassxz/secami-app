import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Plus, Trash2, CalendarOff, X } from 'lucide-react';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const SLOTS = Array.from({ length: 15 }, (_, i) => {
  const h = 7 + i;
  return `${String(h).padStart(2, '0')}:00`;
});

export default function BlockedDates() {
  const { user } = useAuth();
  const [blocks, setBlocks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [form, setForm] = useState({ date: '', slot_start: '', reason: '' });
  const [saving, setSaving] = useState(false);

  const canEdit = ['admin', 'gerente'].includes(user?.role);

  const load = async () => {
    setLoading(true);
    const data = await base44.entities.BlockedDate.list('-date', 200);
    setBlocks(data);
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const handleSave = async () => {
    if (!form.date) return;
    setSaving(true);
    await base44.entities.BlockedDate.create({
      date: form.date,
      slot_start: form.slot_start || null,
      reason: form.reason || null,
    });
    setSaving(false);
    setShowModal(false);
    setForm({ date: '', slot_start: '', reason: '' });
    load();
  };

  const handleDelete = async (id) => {
    if (!confirm('Remover este bloqueio?')) return;
    await base44.entities.BlockedDate.delete(id);
    load();
  };

  const today = format(new Date(), 'yyyy-MM-dd');

  const upcoming = blocks.filter(b => b.date >= today);
  const past = blocks.filter(b => b.date < today);

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Datas Bloqueadas</h1>
          <p className="text-muted-foreground text-sm">Bloqueie dias inteiros ou horários específicos</p>
        </div>
        {canEdit && (
          <button
            onClick={() => setShowModal(true)}
            className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90"
          >
            <Plus className="w-4 h-4" /> Novo Bloqueio
          </button>
        )}
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="space-y-6">
          <Section title="Próximos / Futuros" items={upcoming} onDelete={handleDelete} canEdit={canEdit} />
          {past.length > 0 && <Section title="Passados" items={past} onDelete={handleDelete} canEdit={canEdit} faded />}
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-sm">
            <div className="flex items-center justify-between px-5 py-4 border-b border-border">
              <h2 className="font-semibold text-foreground">Novo Bloqueio</h2>
              <button onClick={() => setShowModal(false)}><X className="w-4 h-4 text-muted-foreground" /></button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Data *</label>
                <input
                  type="date"
                  value={form.date}
                  onChange={e => setForm(f => ({ ...f, date: e.target.value }))}
                  className="w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Horário específico (opcional — vazio = dia inteiro)</label>
                <select
                  value={form.slot_start}
                  onChange={e => setForm(f => ({ ...f, slot_start: e.target.value }))}
                  className="w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring"
                >
                  <option value="">— Dia inteiro —</option>
                  {SLOTS.map(s => <option key={s} value={s}>{s}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Motivo</label>
                <input
                  type="text"
                  value={form.reason}
                  onChange={e => setForm(f => ({ ...f, reason: e.target.value }))}
                  placeholder="Ex: Feriado, manutenção..."
                  className="w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </div>
              <div className="flex gap-3 pt-1">
                <button onClick={() => setShowModal(false)} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Cancelar</button>
                <button onClick={handleSave} disabled={saving || !form.date} className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50">
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

function Section({ title, items, onDelete, canEdit, faded }) {
  if (items.length === 0) return null;
  return (
    <div className="space-y-2">
      <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">{title}</p>
      <div className={`bg-card border border-border rounded-xl overflow-hidden ${faded ? 'opacity-60' : ''}`}>
        {items.map(b => (
          <div key={b.id} className="flex items-center gap-4 px-5 py-3 border-b border-border/50 last:border-0">
            <CalendarOff className="w-4 h-4 text-destructive flex-shrink-0" />
            <div className="flex-1 min-w-0">
              <p className="text-sm font-medium text-foreground">
                {b.date} {b.slot_start ? `· ${b.slot_start}` : '· Dia inteiro'}
              </p>
              {b.reason && <p className="text-xs text-muted-foreground truncate">{b.reason}</p>}
            </div>
            {canEdit && (
              <button onClick={() => onDelete(b.id)} className="p-1.5 text-muted-foreground hover:text-destructive rounded-lg hover:bg-destructive/10 transition-colors">
                <Trash2 className="w-4 h-4" />
              </button>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}