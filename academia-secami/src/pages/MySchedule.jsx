import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Calendar, Plus, X } from 'lucide-react';
import { format, addDays } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const ALL_SLOTS = Array.from({ length: 15 }, (_, i) => {
  const h = 7 + i;
  return { start: `${String(h).padStart(2, '0')}:00`, end: `${String(h + 1).padStart(2, '0')}:00` };
});

export default function MySchedule() {
  const { user } = useAuth();
  const [student, setStudent] = useState(null);
  const [appointments, setAppointments] = useState([]);
  const [checkins, setCheckins] = useState([]);
  const [slotConfigs, setSlotConfigs] = useState([]);
  const [blockedDates, setBlockedDates] = useState([]);
  const [showModal, setShowModal] = useState(false);
  const minDate = format(new Date(), 'yyyy-MM-dd');
  const maxDate = format(addDays(new Date(), 3), 'yyyy-MM-dd');
  const [selectedDate, setSelectedDate] = useState(minDate);
  const [selectedSlot, setSelectedSlot] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const load = async () => {
      // Priorizar sessão do localStorage (login por CPF/email de aluno)
      const session = JSON.parse(localStorage.getItem('studentSession') || 'null');
      let s = null;

      if (session?.student_id) {
        const studs = await base44.entities.Student.filter({ id: session.student_id });
        s = studs[0] || null;
      } else if (user?.id) {
        const studs = await base44.entities.Student.filter({ user_id: user.id });
        s = studs[0] || null;
      }

      setStudent(s);
      if (s) {
        const [appts, configs, cks, blocked] = await Promise.all([
          base44.entities.Appointment.filter({ student_id: s.id }),
          base44.entities.SlotConfig.list(),
          base44.entities.CheckIn.filter({ student_id: s.id }),
          base44.entities.BlockedDate.list(),
        ]);
        setAppointments(appts.sort((a, b) => a.date > b.date ? -1 : 1));
        setSlotConfigs(configs);
        setCheckins(cks);
        setBlockedDates(blocked);
      }
    };
    load();
  }, [user?.id]);

  const isCivil = student?.student_type === 'Civil';

  const getAvailableSlots = () => {
    const now = new Date();
    const maxAllowed = new Date(now.getTime() + 48 * 60 * 60 * 1000);
    return ALL_SLOTS.filter(s => {
      const slotDateTime = new Date(`${selectedDate}T${s.start}:00`);
      if (slotDateTime <= now) return false;
      if (slotDateTime > maxAllowed) return false;

      const config = slotConfigs.find(c => c.slot_start === s.start);
      if (config?.blocked) return false;
      if (isCivil && config?.civil_restricted) return false;
      // Verificar datas bloqueadas (dia inteiro ou slot específico)
      const isDateBlocked = blockedDates.some(b => b.date === selectedDate && (!b.slot_start || b.slot_start === s.start));
      if (isDateBlocked) return false;
      return true;
    });
  };

  const handleBook = async () => {
    if (!selectedSlot || !selectedDate || !student) return;

    // Verificar foto obrigatória para reconhecimento facial
    if (!student.photo_url) {
      alert('Agendamento bloqueado: você não possui foto cadastrada. A foto é obrigatória para o reconhecimento facial da catraca. Procure a recepção para cadastrá-la.');
      return;
    }

    // Revalidar regra das 48h no momento do envio
    const now = new Date();
    const maxAllowed = new Date(now.getTime() + 48 * 60 * 60 * 1000);
    const slotDateTime = new Date(`${selectedDate}T${selectedSlot}:00`);
    if (slotDateTime <= now) {
      alert('Este horário já passou e não pode mais ser agendado.');
      return;
    }
    if (slotDateTime > maxAllowed) {
      alert('Agendamento bloqueado: só é permitido agendar com até 48 horas de antecedência.');
      return;
    }

    // Verificar atestado médico para civis
    if (isCivil) {
      if (!student.atestado_data) {
        alert('Agendamento bloqueado: atestado médico não cadastrado. Procure a recepção.');
        return;
      }
      const atestadoDate = new Date(student.atestado_data + 'T12:00:00');
      const oneYearAgo = new Date();
      oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1);
      if (atestadoDate < oneYearAgo) {
        alert(`Agendamento bloqueado: atestado médico vencido (${atestadoDate.toLocaleDateString('pt-BR')}). Renove o atestado e procure a recepção.`);
        return;
      }
    }
    const activeAppointments = appointments.filter(a => a.date >= format(new Date(), 'yyyy-MM-dd') && a.status !== 'cancelado');
    if (activeAppointments.length >= 2) {
      alert('Você já possui 2 agendamentos ativos. Cancele um antes de fazer um novo agendamento.');
      return;
    }
    const sameDay = appointments.filter(a => a.date === selectedDate && a.status !== 'cancelado');
    if (sameDay.length > 0) {
      alert('Você já possui um agendamento para este dia.');
      return;
    }

    // Verificar se já existe agendamento ativo neste slot exato (evitar duplicatas)
    const allSlotAppts = await base44.entities.Appointment.filter({ date: selectedDate, slot_start: selectedSlot, student_id: student.id });
    const activeInSlot = allSlotAppts.filter(a => a.status !== 'cancelado');
    if (activeInSlot.length > 0) {
      alert('Você já possui um agendamento neste horário.');
      return;
    }
    // Check civil capacity
    if (isCivil) {
      const config = slotConfigs.find(c => c.slot_start === selectedSlot);
      const max = config?.max_capacity || 20;
      const allSlotAppts = await base44.entities.Appointment.filter({ date: selectedDate, slot_start: selectedSlot });
      const civilCount = allSlotAppts.filter(a => a.status !== 'cancelado' && (a.student_type === 'Civil' || !a.student_type)).length;
      if (civilCount >= max) {
        alert('Este horário já está cheio para alunos civis.');
        return;
      }
    }
    setSaving(true);
    const slot = ALL_SLOTS.find(s => s.start === selectedSlot);
    await base44.entities.Appointment.create({
      student_id: student.id,
      student_name: student.full_name,
      student_type: student.student_type || 'Civil',
      date: selectedDate,
      slot_start: selectedSlot,
      slot_end: slot?.end || '',
      status: 'agendado',
    });
    setSaving(false);
    setShowModal(false);
    const appts = await base44.entities.Appointment.filter({ student_id: student.id });
    setAppointments(appts.sort((a, b) => a.date > b.date ? -1 : 1));
  };

  const getCheckinStatus = (appt) => {
    const ck = checkins.find(c => c.date === appt.date);
    if (ck) return 'checkin';
    return appt.status;
  };

  const handleCancel = async (id) => {
    if (!confirm('Deseja cancelar este agendamento?')) return;
    await base44.entities.Appointment.delete(id);
    const appts = await base44.entities.Appointment.filter({ student_id: student.id });
    setAppointments(appts.sort((a, b) => a.date > b.date ? -1 : 1));
  };

  if (!student) {
    return <div className="text-center py-20 text-muted-foreground">Perfil não configurado. Fale com a recepção.</div>;
  }

  const today = format(new Date(), 'yyyy-MM-dd');
  const upcoming = appointments.filter(a => a.date >= today && a.status !== 'cancelado');
  const past = appointments.filter(a => a.date < today && a.status !== 'cancelado' || a.status === 'cancelado');

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Minha Agenda</h1>
          {isCivil && <p className="text-xs text-blue-400 mt-0.5">Horários disponíveis: 07:00 – 18:00</p>}
        </div>
        <button onClick={async () => {
          const blocked = await base44.entities.BlockedDate.list();
          setBlockedDates(blocked);
          setShowModal(true);
        }} className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90">
          <Plus className="w-4 h-4" /> Agendar
        </button>
      </div>

      <div className="space-y-3">
        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Próximos</p>
        {upcoming.length === 0 ? (
          <div className="bg-card border border-border rounded-xl p-6 text-center text-muted-foreground text-sm">Nenhum agendamento futuro.</div>
        ) : (
          upcoming.map(a => (
            <div key={a.id} className="bg-card border border-border rounded-xl flex items-center gap-4 px-5 py-4">
              <div className="text-center">
                <p className="text-2xl font-bold text-primary leading-none">{a.slot_start}</p>
                <p className="text-xs text-muted-foreground">até {a.slot_end}</p>
              </div>
              <div className="flex-1">
                <p className="font-medium text-foreground text-sm">{format(new Date(a.date + 'T12:00:00'), "EEE, dd/MM", { locale: ptBR })}</p>
                <span className="text-xs px-2 py-0.5 rounded-full bg-primary/20 text-primary">{a.status}</span>
              </div>
              <button onClick={() => handleCancel(a.id)} className="flex items-center gap-1 text-xs text-muted-foreground hover:text-destructive border border-border hover:border-destructive/50 px-3 py-1.5 rounded-lg transition-colors">
                <X className="w-3 h-3" /> Desagendar
              </button>
            </div>
          ))
        )}
      </div>

      {past.length > 0 && (
        <div className="space-y-2">
          <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Histórico</p>
          {past.slice(0, 10).map(a => {
            const status = getCheckinStatus(a);
            const statusConfig = {
              checkin: { label: 'Check-in', cls: 'bg-primary/20 text-primary' },
              faltou: { label: 'Falta', cls: 'bg-destructive/20 text-destructive' },
              cancelado: { label: 'Cancelado', cls: 'bg-destructive/20 text-destructive' },
              confirmado: { label: 'Confirmado', cls: 'bg-primary/20 text-primary' },
              agendado: { label: 'Agendado', cls: 'bg-muted text-muted-foreground' },
            }[status] || { label: status, cls: 'bg-muted text-muted-foreground' };
            return (
              <div key={a.id} className="bg-card border border-border rounded-xl flex items-center gap-4 px-5 py-3 opacity-60">
                <p className="text-sm font-medium text-muted-foreground">{a.slot_start} – {a.slot_end}</p>
                <p className="text-xs text-muted-foreground flex-1">{a.date}</p>
                <span className={`text-xs px-2 py-0.5 rounded-full ${statusConfig.cls}`}>{statusConfig.label}</span>
              </div>
            );
          })}
        </div>
      )}

      {showModal && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-sm">
            <div className="flex items-center justify-between px-5 py-4 border-b border-border">
              <h2 className="font-semibold text-foreground">Agendar Horário</h2>
              <button onClick={() => setShowModal(false)}><X className="w-4 h-4 text-muted-foreground" /></button>
            </div>
            <div className="p-5 space-y-4">
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Data</label>
                <input
                  type="date"
                  value={selectedDate}
                  min={minDate}
                  max={maxDate}
                  onChange={e => setSelectedDate(e.target.value)}
                  className="w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring"
                />
              </div>
              <div>
                <label className="block text-xs text-muted-foreground mb-1">Janela de Horário</label>
                {blockedDates.some(b => b.date === selectedDate && !b.slot_start) && (
                  <div className="mb-2 px-3 py-2 bg-destructive/10 border border-destructive/30 rounded-lg text-xs text-destructive font-medium">
                    ⚠️ Esta data está bloqueada: {blockedDates.find(b => b.date === selectedDate && !b.slot_start)?.reason || 'Indisponível'}
                  </div>
                )}
                <div className="grid grid-cols-2 gap-2 max-h-56 overflow-y-auto pr-1">
                  {getAvailableSlots().length === 0 ? (
                    <div className="col-span-2 text-center py-4 text-xs text-muted-foreground">
                      Nenhum horário disponível para esta data.
                    </div>
                  ) : getAvailableSlots().map(s => (
                    <button
                      key={s.start}
                      onClick={() => setSelectedSlot(s.start)}
                      className={`py-2.5 px-3 rounded-lg text-sm font-medium border transition-colors text-left ${
                        selectedSlot === s.start
                          ? 'bg-primary text-primary-foreground border-primary'
                          : 'bg-background border-border text-muted-foreground hover:border-primary/50'
                      }`}
                    >
                      {s.start} – {s.end}
                    </button>
                  ))}
                </div>
              </div>
              <div className="flex gap-3 pt-1">
                <button onClick={() => setShowModal(false)} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Cancelar</button>
                <button onClick={handleBook} disabled={saving || !selectedSlot} className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50">
                  {saving ? 'Agendando...' : 'Confirmar'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}