import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { ChevronLeft, ChevronRight, Users, Plus, X, Trash2, LayoutList, Hash } from 'lucide-react';
import { format, addDays, startOfWeek } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const HOURS = Array.from({ length: 15 }, (_, i) => {
  const h = 7 + i;
  return `${String(h).padStart(2, '0')}:00`;
});

export default function Schedule() {
  const { user } = useAuth();
  const [appointments, setAppointments] = useState([]);
  const [slotConfigs, setSlotConfigs] = useState([]);
  const [weekStart, setWeekStart] = useState(startOfWeek(new Date(), { weekStartsOn: 1 }));
  const [loading, setLoading] = useState(true);
  const [modal, setModal] = useState(null); // { date, hour }
  const [students, setStudents] = useState([]);
  const [studentSearch, setStudentSearch] = useState('');
  const [saving, setSaving] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(null); // appointment id
  const [viewMode, setViewMode] = useState('count'); // 'count' | 'detail'
  const [blockedDates, setBlockedDates] = useState([]);

  const isStudent = user?.role === 'aluno' || user?.role === 'user';
  const isStaff = ['admin', 'gerente', 'recepcao'].includes(user?.role);

  const weekDays = Array.from({ length: 5 }, (_, i) => addDays(weekStart, i));

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const startStr = format(weekStart, 'yyyy-MM-dd');
      const endStr = format(addDays(weekStart, 6), 'yyyy-MM-dd');
      const [appts, configs, blocked] = await Promise.all([
        base44.entities.Appointment.list('-date', 500),
        base44.entities.SlotConfig.list(),
        base44.entities.BlockedDate.list('-date', 200),
      ]);
      const filtered = appts.filter(a => a.date >= startStr && a.date <= endStr && a.status !== 'cancelado');
      setAppointments(filtered);
      setSlotConfigs(configs);
      setBlockedDates(blocked);
      setLoading(false);
    };
    load();
  }, [weekStart]);

  const loadStudents = async () => {
    const data = await base44.entities.Student.list('-full_name', 200);
    setStudents(data.filter(s => s.active !== false));
  };

  const openModal = (date, hour) => {
    setModal({ date: format(date, 'yyyy-MM-dd'), hour });
    setStudentSearch('');
    loadStudents();
  };

  const handleCreate = async (student) => {
    // Verificar foto obrigatória para reconhecimento facial
    if (!student.photo_url) {
      alert(`Agendamento bloqueado: ${student.full_name} não possui foto cadastrada. A foto é obrigatória para o reconhecimento facial da catraca.`);
      return;
    }
    // Verificar atestado médico para civis
    if (student.student_type === 'Civil') {
      if (!student.atestado_data) {
        alert(`Atenção: ${student.full_name} não possui atestado médico cadastrado. Agendamento bloqueado.`);
        return;
      }
      const atestadoDate = new Date(student.atestado_data + 'T12:00:00');
      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
      if (atestadoDate < oneYearAgo) {
        alert(`Atenção: atestado de ${student.full_name} está vencido (${atestadoDate.toLocaleDateString('pt-BR')}). Agendamento bloqueado.`);
        return;
      }
    }
    setSaving(true);
    const config = getConfig(modal.hour);
    const [h] = modal.hour.split(':').map(Number);
    const slotEnd = `${String(h + 1).padStart(2, '0')}:00`;
    await base44.entities.Appointment.create({
      student_id: student.id,
      student_name: student.full_name,
      student_type: student.student_type || 'Civil',
      date: modal.date,
      slot_start: modal.hour,
      slot_end: slotEnd,
      status: 'agendado',
      forced: true,
    });
    setSaving(false);
    setModal(null);
    // reload
    const startStr = format(weekStart, 'yyyy-MM-dd');
    const endStr = format(addDays(weekStart, 6), 'yyyy-MM-dd');
    const appts = await base44.entities.Appointment.list('-date', 500);
    setAppointments(appts.filter(a => a.date >= startStr && a.date <= endStr && a.status !== 'cancelado'));
  };

  const handleDelete = async (apptId) => {
    await base44.entities.Appointment.delete(apptId);
    setConfirmDelete(null);
    const startStr = format(weekStart, 'yyyy-MM-dd');
    const endStr = format(addDays(weekStart, 6), 'yyyy-MM-dd');
    const appts = await base44.entities.Appointment.list('-date', 500);
    setAppointments(appts.filter(a => a.date >= startStr && a.date <= endStr && a.status !== 'cancelado'));
  };

  const getAppts = (date, hour) => {
    const dateStr = format(date, 'yyyy-MM-dd');
    return appointments.filter(a => a.date === dateStr && a.slot_start === hour);
  };

  const getConfig = (hour) => slotConfigs.find(c => c.slot_start === hour);

  const isBlocked = (date, hour) => {
    const dateStr = format(date, 'yyyy-MM-dd');
    return blockedDates.some(b => b.date === dateStr && (!b.slot_start || b.slot_start === hour));
  };

  const getBlockReason = (date, hour) => {
    const dateStr = format(date, 'yyyy-MM-dd');
    const b = blockedDates.find(b => b.date === dateStr && (!b.slot_start || b.slot_start === hour));
    return b?.reason || 'Bloqueado';
  };

  return (
    <>
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-foreground">Agenda</h1>
        <div className="flex items-center gap-2">
          {isStaff && (
            <button
              onClick={() => setViewMode(v => v === 'count' ? 'detail' : 'count')}
              className="p-2 rounded-lg border border-border text-muted-foreground hover:text-foreground hover:bg-muted/30 transition-colors"
              title={viewMode === 'count' ? 'Ver nomes' : 'Ver contagem'}
            >
              {viewMode === 'count' ? <LayoutList className="w-4 h-4" /> : <Hash className="w-4 h-4" />}
            </button>
          )}
          <button
            onClick={() => setWeekStart(addDays(weekStart, -7))}
            className="p-2 rounded-lg border border-border text-muted-foreground hover:text-foreground hover:bg-muted/30 transition-colors"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>
          <span className="text-sm text-muted-foreground min-w-[140px] text-center">
            {format(weekStart, "dd/MM", { locale: ptBR })} – {format(addDays(weekStart, 6), "dd/MM/yyyy", { locale: ptBR })}
          </span>
          <button
            onClick={() => setWeekStart(addDays(weekStart, 7))}
            className="p-2 rounded-lg border border-border text-muted-foreground hover:text-foreground hover:bg-muted/30 transition-colors"
          >
            <ChevronRight className="w-4 h-4" />
          </button>
        </div>
      </div>

      {loading ? (
        <div className="flex justify-center py-16">
          <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full border-collapse text-sm">
            <thead>
              <tr>
                <th className="w-16 p-2 text-left text-xs text-muted-foreground font-medium">Hora</th>
                {weekDays.map(d => (
                  <th key={d.toString()} className="p-2 text-center text-xs font-medium text-muted-foreground min-w-[90px]">
                    <div>{format(d, 'EEE', { locale: ptBR })}</div>
                    <div className={`text-base font-bold ${format(d, 'yyyy-MM-dd') === format(new Date(), 'yyyy-MM-dd') ? 'text-primary' : 'text-foreground'}`}>
                      {format(d, 'dd')}
                    </div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {HOURS.map(hour => {
                const config = getConfig(hour);
                if (config?.blocked) return null;
                return (
                  <tr key={hour} className="border-t border-border/50">
                    <td className="p-2 text-xs text-muted-foreground font-medium">{hour}</td>
                    {weekDays.map(d => {
                      if (isBlocked(d, hour)) {
                        return (
                          <td key={d.toString()} className="p-1 align-top">
                            <div className="rounded-lg bg-destructive/10 border border-destructive/20 p-1.5 min-h-[32px] flex items-center justify-center">
                              <span className="text-[10px] text-destructive/70 text-center">{getBlockReason(d, hour)}</span>
                            </div>
                          </td>
                        );
                      }
                      const appts = getAppts(d, hour);
                            const civilAppts = appts.filter(a => a.student_type === 'Civil');
                            const militarAppts = appts.filter(a => a.student_type === 'Militar');
                            const max = config?.max_capacity || 20;
                      return (
                        <td key={d.toString()} className="p-1 align-top">
                          <div className="rounded-lg bg-primary/10 border border-primary/20 p-1.5 space-y-1 min-h-[32px] relative group">
                           {(isStudent || viewMode === 'count') ? (
                               <div className="space-y-0.5">
                                 <div className="flex items-center gap-1 text-xs text-blue-400 font-medium">
                                   <Users className="w-3 h-3" />
                                   <span>Civil: {civilAppts.length}/{max}</span>
                                 </div>
                                 <div className="flex items-center gap-1 text-xs text-orange-400 font-medium">
                                   <Users className="w-3 h-3" />
                                   <span>Mil: {militarAppts.length}</span>
                                 </div>
                               </div>
                             ) : (
                               appts.map(a => (
                                  <div key={a.id} className="flex items-center justify-between gap-1 text-xs text-foreground">
                                    <span className="font-medium truncate">{a.student_name}</span>
                                    <div className="flex items-center gap-0.5 flex-shrink-0">
                                      <span className={`px-1 rounded text-[10px] ${
                                        a.status === 'confirmado' ? 'bg-primary/20 text-primary' :
                                        a.status === 'faltou' ? 'bg-destructive/20 text-destructive' :
                                        'bg-muted text-muted-foreground'
                                      }`}>{a.status}</span>
                                      {isStaff && (
                                        <button
                                          onClick={() => setConfirmDelete(a.id)}
                                          className="p-0.5 text-muted-foreground hover:text-destructive rounded"
                                        >
                                          <Trash2 className="w-3 h-3" />
                                        </button>
                                      )}
                                    </div>
                                  </div>
                                ))
                              )}
                            {isStaff && viewMode === 'detail' && appts.length === 0 && (
                              <button
                                onClick={() => openModal(d, hour)}
                                className="w-full h-full flex items-center justify-center text-muted-foreground/40 hover:text-primary hover:bg-primary/10 rounded transition-colors"
                              >
                                <Plus className="w-3 h-3" />
                              </button>
                            )}
                            {isStaff && viewMode === 'detail' && appts.length > 0 && appts.length < max && (
                              <button
                                onClick={() => openModal(d, hour)}
                                className="w-full flex items-center justify-center text-muted-foreground/40 hover:text-primary text-xs gap-0.5 mt-1"
                              >
                                <Plus className="w-3 h-3" />
                              </button>
                            )}

                          </div>
                        </td>
                      );
                    })}
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}
    </div>

    {/* Modal de novo agendamento */}
    {modal && (
      <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
        <div className="bg-card border border-border rounded-2xl w-full max-w-sm">
          <div className="flex items-center justify-between px-5 py-4 border-b border-border">
            <h2 className="font-semibold text-foreground text-sm">
              Agendar · {modal.hour} · {modal.date}
            </h2>
            <button onClick={() => setModal(null)}><X className="w-4 h-4 text-muted-foreground" /></button>
          </div>
          <div className="p-5 space-y-3">
            <input
              autoFocus
              value={studentSearch}
              onChange={e => setStudentSearch(e.target.value)}
              placeholder="Buscar aluno..."
              className="w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
            />
            <div className="max-h-56 overflow-y-auto space-y-1">
              {students
                .filter(s => s.full_name?.toLowerCase().includes(studentSearch.toLowerCase()) || s.cpf?.includes(studentSearch))
                .map(s => (
                  <button
                    key={s.id}
                    onClick={() => handleCreate(s)}
                    disabled={saving}
                    className="w-full text-left px-3 py-2.5 rounded-lg hover:bg-muted/40 transition-colors text-sm text-foreground disabled:opacity-50"
                  >
                    <span className="font-medium">{s.full_name}</span>
                    <span className="text-muted-foreground text-xs ml-2">{s.cpf}</span>
                  </button>
                ))
              }
            </div>
          </div>
        </div>
      </div>
    )}

    {/* Confirm delete */}
    {confirmDelete && (
      <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
        <div className="bg-card border border-border rounded-2xl w-full max-w-xs p-6 space-y-4">
          <p className="text-foreground text-sm font-medium">Remover este agendamento?</p>
          <div className="flex gap-3">
            <button onClick={() => setConfirmDelete(null)} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Cancelar</button>
            <button onClick={() => handleDelete(confirmDelete)} className="flex-1 py-2 bg-destructive text-destructive-foreground rounded-lg text-sm font-medium hover:bg-destructive/90">Remover</button>
          </div>
        </div>
      </div>
    )}
    </>
  );
}