import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Activity, Calendar, Dumbbell } from 'lucide-react';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

export default function MyHistory() {
  const { user } = useAuth();
  const [student, setStudent] = useState(null);
  const [checkins, setCheckins] = useState([]);
  const [workoutLogs, setWorkoutLogs] = useState([]);

  useEffect(() => {
    const load = async () => {
      const studs = await base44.entities.Student.filter({ user_id: user?.id });
      const s = studs[0];
      setStudent(s);
      if (s) {
        const [cins, logs] = await Promise.all([
          base44.entities.CheckIn.filter({ student_id: s.id }),
          base44.entities.WorkoutLog.filter({ student_id: s.id }),
        ]);
        setCheckins(cins.sort((a, b) => b.date > a.date ? 1 : -1));
        setWorkoutLogs(logs.sort((a, b) => b.date > a.date ? 1 : -1));
      }
    };
    load();
  }, []);

  if (!student) return <div className="text-center py-20 text-muted-foreground">Perfil não configurado.</div>;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Meu Histórico</h1>
        <p className="text-muted-foreground text-sm">{student.full_name}</p>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div className="bg-card border border-border rounded-xl p-4 text-center">
          <p className="text-3xl font-bold text-primary">{checkins.length}</p>
          <p className="text-xs text-muted-foreground mt-1">Check-ins Totais</p>
        </div>
        <div className="bg-card border border-border rounded-xl p-4 text-center">
          <p className="text-3xl font-bold text-primary">{workoutLogs.filter(l => l.completed).length}</p>
          <p className="text-xs text-muted-foreground mt-1">Treinos Completos</p>
        </div>
      </div>

      <div>
        <h2 className="font-semibold text-foreground mb-3 flex items-center gap-2">
          <Calendar className="w-4 h-4 text-primary" /> Presença
        </h2>
        <div className="bg-card border border-border rounded-xl divide-y divide-border overflow-hidden">
          {checkins.length === 0 ? (
            <p className="text-center py-8 text-muted-foreground text-sm">Nenhum check-in registrado.</p>
          ) : (
            checkins.slice(0, 20).map(c => (
              <div key={c.id} className="flex items-center justify-between px-5 py-3">
                <p className="text-sm text-foreground">{format(new Date(c.date + 'T12:00:00'), "EEE, dd/MM/yyyy", { locale: ptBR })}</p>
                <span className="text-xs text-muted-foreground">{c.check_in_time}</span>
              </div>
            ))
          )}
        </div>
      </div>

      <div>
        <h2 className="font-semibold text-foreground mb-3 flex items-center gap-2">
          <Dumbbell className="w-4 h-4 text-primary" /> Treinos
        </h2>
        <div className="bg-card border border-border rounded-xl divide-y divide-border overflow-hidden">
          {workoutLogs.length === 0 ? (
            <p className="text-center py-8 text-muted-foreground text-sm">Nenhum treino registrado.</p>
          ) : (
            workoutLogs.slice(0, 20).map(l => (
              <div key={l.id} className="flex items-center justify-between px-5 py-3">
                <div>
                  <p className="text-sm text-foreground">{format(new Date(l.date + 'T12:00:00'), "EEE, dd/MM/yyyy", { locale: ptBR })}</p>
                  <p className="text-xs text-muted-foreground">Ficha {l.sheet_label} · {l.completed_exercises?.length || 0} exercícios</p>
                </div>
                {l.completed && <span className="text-xs px-2 py-0.5 rounded-full bg-primary/20 text-primary">Completo</span>}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
}