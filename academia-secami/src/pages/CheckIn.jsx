import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { Search, UserCheck, LogOut, Undo2, CheckCircle2, ChevronLeft, ChevronRight, LayoutList, Clock, XCircle, X } from 'lucide-react';
import { format, addDays } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default function CheckIn() {
  const [date, setDate] = useState(format(new Date(), 'yyyy-MM-dd'));
  const [search, setSearch] = useState('');
  const [students, setStudents] = useState([]);
  const [appointments, setAppointments] = useState([]);
  const [checkins, setCheckins] = useState([]);
  const [loading, setLoading] = useState(true);
  const [view, setView] = useState('slots'); // 'list' | 'slots'
  const [confirmUndo, setConfirmUndo] = useState(null);
  const [photoModal, setPhotoModal] = useState(null); // { name, photo_url }

  const load = async () => {
    setLoading(true);
    const [appts, cks] = await Promise.all([
      base44.entities.Appointment.filter({ date }),
      base44.entities.CheckIn.filter({ date }),
    ]);
    const activeAppts = appts.filter(a => a.status !== 'cancelado');
    const studentIds = [...new Set(activeAppts.map(a => a.student_id))];
    let studs = [];
    if (studentIds.length > 0) {
      const all = await base44.entities.Student.list();
      studs = all.filter(s => studentIds.includes(s.id));
    }
    setAppointments(activeAppts);
    setCheckins(cks);
    setStudents(studs);
    setLoading(false);
  };

  useEffect(() => { load(); }, [date]);

  const getCheckin = (studentId) => checkins.find(c => c.student_id === studentId);
  const getAppt = (studentId) => appointments.find(a => a.student_id === studentId);

  const handleCheckin = async (student) => {
    const now = format(new Date(), 'HH:mm');
    const appt = getAppt(student.id);
    await base44.entities.CheckIn.create({
      student_id: student.id,
      student_name: student.full_name,
      appointment_id: appt?.id || '',
      check_in_time: now,
      date,
    });
    load();
  };

  const handleCheckout = async (checkin) => {
    const now = format(new Date(), 'HH:mm');
    await base44.entities.CheckIn.update(checkin.id, { check_out_time: now });
    load();
  };

  const handleUndo = async (checkin) => {
    await base44.entities.CheckIn.delete(checkin.id);
    setConfirmUndo(null);
    load();
  };

  const handleMarkAbsent = async (student) => {
    const appt = getAppt(student.id);
    if (appt) await base44.entities.Appointment.update(appt.id, { status: 'faltou' });
    load();
  };

  const handleUndoAbsent = async (student) => {
    const appt = getAppt(student.id);
    if (appt) await base44.entities.Appointment.update(appt.id, { status: 'agendado' });
    load();
  };

  const filtered = students.filter(s =>
    s.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    s.cpf?.includes(search)
  );

  // Group by slot for slot view
  const slots = [...new Set(appointments.map(a => a.slot_start))].sort();

  const StudentRow = ({ student }) => {
    const checkin = getCheckin(student.id);
    const appt = getAppt(student.id);
    const done = checkin?.check_in_time && checkin?.check_out_time;

    return (
      <div className="px-4 py-3 hover:bg-muted/20 transition-colors">
        <div className="flex items-center gap-3">
          <button
            onClick={() => student.photo_url && setPhotoModal({ name: student.full_name, photo_url: student.photo_url })}
            className={`w-9 h-9 rounded-full flex-shrink-0 overflow-hidden border-2 ${student.photo_url ? 'border-primary/40 hover:border-primary cursor-pointer' : 'border-transparent cursor-default'}`}
          >
            {student.photo_url ? (
              <img src={student.photo_url} alt={student.full_name} className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full bg-primary/20 flex items-center justify-center text-primary font-semibold text-sm">
                {student.full_name?.[0]?.toUpperCase()}
              </div>
            )}
          </button>
          <div className="flex-1 min-w-0">
            <p className="font-medium text-foreground text-sm truncate">{student.full_name}</p>
            <p className="text-xs text-muted-foreground">{appt ? `${appt.slot_start} – ${appt.slot_end}` : '–'}</p>
          </div>
          {done && (
            <div className="flex flex-col items-end gap-0.5 flex-shrink-0">
              <span className="flex items-center gap-1 text-xs text-primary font-medium px-2 py-1 bg-primary/10 rounded-full">
                <CheckCircle2 className="w-3 h-3" /> Concluído
              </span>
              <span className="text-xs text-muted-foreground px-2">
                Entrada: {checkin.check_in_time} · Saída: {checkin.check_out_time}
              </span>
            </div>
          )}
          {!done && appt?.status === 'faltou' && (
            <span className="flex items-center gap-1 text-xs text-destructive font-medium px-2 py-1 bg-destructive/10 rounded-full flex-shrink-0">
              <XCircle className="w-3 h-3" /> Falta
            </span>
          )}
        </div>

        {/* Actions row */}
        {!done && (
          <div className="mt-2 ml-12 flex flex-wrap items-center gap-2">
            {checkin ? (
              <>
                <span className="text-xs text-muted-foreground">Check-in: {checkin.check_in_time}</span>
                <button
                  onClick={() => handleCheckout(checkin)}
                  className="flex items-center gap-1 text-xs bg-orange-500/20 text-orange-400 hover:bg-orange-500/30 px-3 py-1.5 rounded-lg transition-colors font-medium"
                >
                  <LogOut className="w-3 h-3" /> Check-out
                </button>
                {confirmUndo === student.id ? (
                  <div className="flex items-center gap-1">
                    <button onClick={() => handleUndo(checkin)} className="text-xs text-destructive hover:underline">Confirmar</button>
                    <button onClick={() => setConfirmUndo(null)} className="text-xs text-muted-foreground hover:underline">Cancelar</button>
                  </div>
                ) : (
                  <button onClick={() => setConfirmUndo(student.id)} className="p-1.5 text-muted-foreground hover:text-destructive rounded-lg hover:bg-destructive/10 transition-colors">
                    <Undo2 className="w-3.5 h-3.5" />
                  </button>
                )}
              </>
            ) : appt?.status === 'faltou' ? (
              <button onClick={() => handleUndoAbsent(student)} className="text-xs text-muted-foreground hover:text-foreground border border-border px-2 py-1 rounded-lg hover:bg-muted/30 transition-colors">
                Desfazer falta
              </button>
            ) : (
              <>
                <button
                  onClick={() => handleCheckin(student)}
                  className="flex items-center gap-1.5 text-xs bg-primary text-primary-foreground hover:bg-primary/90 px-3 py-1.5 rounded-lg transition-colors font-medium"
                >
                  <UserCheck className="w-3 h-3" /> Check-in
                </button>
                <button
                  onClick={() => handleMarkAbsent(student)}
                  className="flex items-center gap-1.5 text-xs bg-destructive/20 text-destructive hover:bg-destructive/30 px-3 py-1.5 rounded-lg transition-colors font-medium"
                >
                  <XCircle className="w-3 h-3" /> Falta
                </button>
              </>
            )}
          </div>
        )}
      </div>
    );
  };

  return (
    <>
    {photoModal && (
      <div className="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4" onClick={() => setPhotoModal(null)}>
        <div className="bg-card border border-border rounded-2xl overflow-hidden max-w-xs w-full" onClick={e => e.stopPropagation()}>
          <div className="flex items-center justify-between px-4 py-3 border-b border-border">
            <p className="font-semibold text-sm text-foreground">{photoModal.name}</p>
            <button onClick={() => setPhotoModal(null)}><X className="w-4 h-4 text-muted-foreground" /></button>
          </div>
          <img src={photoModal.photo_url} alt={photoModal.name} className="w-full object-cover max-h-80" />
        </div>
      </div>
    )}
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Check-in</h1>
          <p className="text-xs text-muted-foreground mt-0.5">{checkins.length} check-ins hoje</p>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={() => setView(v => v === 'slots' ? 'list' : 'slots')} className="flex items-center gap-1.5 px-3 py-2 rounded-lg border border-border text-xs text-muted-foreground hover:text-foreground hover:bg-muted/30 transition-colors">
            {view === 'slots' ? <><LayoutList className="w-4 h-4" /> Lista</> : <><Clock className="w-4 h-4" /> Por horário</>}
          </button>
        </div>
      </div>

      {/* Date navigation */}
      <div className="flex items-center gap-2">
        <button onClick={() => setDate(format(addDays(new Date(date + 'T12:00:00'), -1), 'yyyy-MM-dd'))} className="p-2 rounded-lg border border-border text-muted-foreground hover:text-foreground hover:bg-muted/30 transition-colors">
          <ChevronLeft className="w-4 h-4" />
        </button>
        <input
          type="date"
          value={date}
          onChange={e => setDate(e.target.value)}
          className="flex-1 bg-card border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring text-center"
        />
        <button onClick={() => setDate(format(addDays(new Date(date + 'T12:00:00'), 1), 'yyyy-MM-dd'))} className="p-2 rounded-lg border border-border text-muted-foreground hover:text-foreground hover:bg-muted/30 transition-colors">
          <ChevronRight className="w-4 h-4" />
        </button>
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Buscar aluno..."
          className="w-full bg-card border border-border rounded-lg pl-10 pr-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
        />
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : filtered.length === 0 ? (
        <div className="bg-card border border-border rounded-xl p-10 text-center text-muted-foreground">
          <UserCheck className="w-10 h-10 mx-auto mb-3 opacity-30" />
          <p>Nenhum aluno agendado para esta data.</p>
        </div>
      ) : view === 'list' ? (
        <div className="bg-card border border-border rounded-xl overflow-hidden divide-y divide-border">
          {filtered.map(s => <StudentRow key={s.id} student={s} />)}
        </div>
      ) : (
        <div className="space-y-4">
          {slots.map(slot => {
            const slotStudents = filtered.filter(s => getAppt(s.id)?.slot_start === slot);
            if (slotStudents.length === 0) return null;
            return (
              <div key={slot} className="bg-card border border-border rounded-xl overflow-hidden">
                <div className="px-4 py-2.5 bg-muted/30 border-b border-border">
                  <p className="text-sm font-semibold text-foreground">{slot}</p>
                  <p className="text-xs text-muted-foreground">{slotStudents.length} aluno(s)</p>
                </div>
                <div className="divide-y divide-border">
                  {slotStudents.map(s => <StudentRow key={s.id} student={s} />)}
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
    </>
  );
}