import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { AlertTriangle, Clock } from 'lucide-react';
import { format } from 'date-fns';

export default function StudentsOvertime() {
  const [overtime, setOvertime] = useState([]);

  useEffect(() => {
    const load = async () => {
      const today = format(new Date(), 'yyyy-MM-dd');

      const [appointments, checkins] = await Promise.all([
        base44.entities.Appointment.filter({ date: today }),
        base44.entities.CheckIn.filter({ date: today }),
      ]);

      const now = new Date();
      const brNow = new Date(now.toLocaleString('en-US', { timeZone: 'America/Sao_Paulo' }));
      const curH = brNow.getHours();
      const curM = brNow.getMinutes();
      const curMinutes = curH * 60 + curM;

      const result = [];

      for (const appt of appointments) {
        if (appt.status === 'cancelado') continue;

        const checkin = checkins.find(c => c.student_id === appt.student_id);

        // Only show students who checked in but haven't checked out
        if (!checkin || checkin.check_out_time) continue;

        const [endH, endM] = appt.slot_end.split(':').map(Number);
        const endMinutes = endH * 60 + endM;

        if (curMinutes >= endMinutes + 15) {
          result.push({
            student_name: appt.student_name,
            slot_start: appt.slot_start,
            slot_end: appt.slot_end,
            check_in_time: checkin.check_in_time,
            overdue_minutes: curMinutes - endMinutes,
          });
        }
      }

      setOvertime(result.sort((a, b) => b.overdue_minutes - a.overdue_minutes));
    };

    load();
    const interval = setInterval(load, 60000);
    return () => clearInterval(interval);
  }, []);

  if (overtime.length === 0) return null;

  return (
    <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-xl overflow-hidden">
      <div className="px-5 py-3 border-b border-yellow-500/20 flex items-center gap-2">
        <AlertTriangle className="w-4 h-4 text-yellow-400" />
        <h2 className="font-semibold text-yellow-300 text-sm">
          Alunos com horário excedido ({overtime.length})
        </h2>
      </div>
      <div className="divide-y divide-yellow-500/10">
        {overtime.map((s, i) => (
          <div key={i} className="flex items-center justify-between px-5 py-3">
            <div>
              <p className="text-sm font-medium text-foreground">{s.student_name}</p>
              <p className="text-xs text-muted-foreground">
                Horário: {s.slot_start} – {s.slot_end} · Check-in: {s.check_in_time}
              </p>
            </div>
            <div className="flex items-center gap-1.5 text-yellow-400 text-xs font-semibold">
              <Clock className="w-3.5 h-3.5" />
              +{s.overdue_minutes} min
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}