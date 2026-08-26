import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Settings, Lock, Unlock, Save } from 'lucide-react';

const ALL_SLOTS = Array.from({ length: 15 }, (_, i) => {
  const h = 7 + i;
  return { start: `${String(h).padStart(2, '0')}:00`, end: `${String(h + 1).padStart(2, '0')}:00` };
});

export default function SlotConfig() {
  const { user } = useAuth();
  const role = user?.role;
  const [configs, setConfigs] = useState({});
  const [saving, setSaving] = useState({});
  const [loaded, setLoaded] = useState(false);

  const load = async () => {
    const data = await base44.entities.SlotConfig.list();
    const map = {};
    data.forEach(c => { map[c.slot_start] = c; });
    setConfigs(map);
    setLoaded(true);
  };

  useEffect(() => { load(); }, []);

  if (!['admin', 'gerente'].includes(role)) {
    return <div className="text-center py-20 text-muted-foreground">Acesso restrito.</div>;
  }

  const getConfig = (start) => configs[start] || { slot_start: start, blocked: false, block_reason: '', civil_restricted: false, max_capacity: 20 };

  const updateConfig = (start, field, value) => {
    setConfigs(prev => ({
      ...prev,
      [start]: { ...getConfig(start), [field]: value }
    }));
  };

  const saveSlot = async (start) => {
    setSaving(prev => ({ ...prev, [start]: true }));
    const config = getConfig(start);
    const existing = Object.values(configs).find(c => c.id && c.slot_start === start);
    const slot = ALL_SLOTS.find(s => s.start === start);
    if (existing?.id) {
      await base44.entities.SlotConfig.update(existing.id, config);
    } else {
      const created = await base44.entities.SlotConfig.create({ ...config, slot_end: slot?.end });
      setConfigs(prev => ({ ...prev, [start]: created }));
    }
    setSaving(prev => ({ ...prev, [start]: false }));
  };

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-bold text-foreground flex items-center gap-2">
          <Settings className="w-6 h-6 text-primary" />
          Configuração de Horários
        </h1>
        <p className="text-muted-foreground text-sm mt-1">Gerencie as janelas de agendamento disponíveis</p>
      </div>

      {!loaded ? (
        <div className="flex justify-center py-12">
          <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="space-y-3">
          {ALL_SLOTS.map(slot => {
            const config = getConfig(slot.start);
            return (
              <div key={slot.start} className={`bg-card border rounded-xl p-4 transition-all ${config.blocked ? 'border-destructive/40' : 'border-border'}`}>
                <div className="flex items-center gap-4 flex-wrap">
                  <div className="flex items-center gap-2 w-28 flex-shrink-0">
                    {config.blocked
                      ? <Lock className="w-4 h-4 text-destructive" />
                      : <Unlock className="w-4 h-4 text-primary" />}
                    <span className="font-semibold text-foreground text-sm">{slot.start} – {slot.end}</span>
                  </div>

                  <label className="flex items-center gap-1.5 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={!!config.blocked}
                      onChange={e => updateConfig(slot.start, 'blocked', e.target.checked)}
                      className="accent-destructive"
                    />
                    <span className="text-sm text-muted-foreground">Bloqueado</span>
                  </label>

                  {config.blocked && (
                    <input
                      value={config.block_reason || ''}
                      onChange={e => updateConfig(slot.start, 'block_reason', e.target.value)}
                      placeholder="Motivo do bloqueio..."
                      className="flex-1 bg-background border border-border rounded-lg px-3 py-1.5 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring min-w-40"
                    />
                  )}

                  <label className="flex items-center gap-1.5 cursor-pointer">
                    <input
                      type="checkbox"
                      checked={!!config.civil_restricted}
                      onChange={e => updateConfig(slot.start, 'civil_restricted', e.target.checked)}
                      className="accent-primary"
                    />
                    <span className="text-sm text-muted-foreground">Rest. Civis</span>
                  </label>

                  <div className="flex items-center gap-1.5">
                    <span className="text-xs text-muted-foreground">Cap:</span>
                    <input
                      type="number"
                      value={config.max_capacity || 20}
                      onChange={e => updateConfig(slot.start, 'max_capacity', parseInt(e.target.value))}
                      className="w-16 bg-background border border-border rounded px-2 py-1 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring"
                    />
                  </div>

                  <button
                    onClick={() => saveSlot(slot.start)}
                    disabled={saving[slot.start]}
                    className="ml-auto flex items-center gap-1.5 bg-primary text-primary-foreground px-3 py-1.5 rounded-lg text-xs font-medium hover:bg-primary/90 transition-colors disabled:opacity-50"
                  >
                    <Save className="w-3 h-3" />
                    {saving[slot.start] ? 'Salvando...' : 'Salvar'}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}