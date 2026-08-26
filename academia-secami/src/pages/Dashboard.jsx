import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Users, Calendar, UserCheck, Dumbbell, Clock, Bell, AlertTriangle, Star } from 'lucide-react';
import { differenceInDays, parseISO, addYears } from 'date-fns';
import StudentsOvertime from '../components/StudentsOvertime';
import { format } from 'date-fns';
import { ptBR } from 'date-fns/locale';

function StatCard({ icon: Icon, label, value, color = 'text-primary' }) {
  return (
    <div className="bg-card border border-border rounded-xl p-5 flex items-center gap-4">
      <div className={`w-12 h-12 rounded-xl bg-primary/10 flex items-center justify-center ${color}`}>
        <Icon className="w-5 h-5" />
      </div>
      <div>
        <p className="text-muted-foreground text-sm">{label}</p>
        <p className="text-2xl font-bold text-foreground">{value}</p>
      </div>
    </div>
  );
}

export default function Dashboard() {
  const { user } = useAuth();
  const [stats, setStats] = useState({ students: 0, todayAppointments: 0, todayCheckins: 0 });
  const [recentAppointments, setRecentAppointments] = useState([]);
  const [notices, setNotices] = useState([]);
  const [myStudent, setMyStudent] = useState(null);
  const today = format(new Date(), 'yyyy-MM-dd');

  const role = user?.role || 'aluno';

  useEffect(() => {
    const load = async () => {
      const [students, appointments, checkins] = await Promise.all([
        base44.entities.Student.list(),
        base44.entities.Appointment.filter({ date: today }),
        base44.entities.CheckIn.filter({ date: today }),
      ]);
      setStats({
        students: students.filter(s => s.active !== false).length,
        todayAppointments: appointments.filter(a => a.status !== 'cancelado').length,
        todayCheckins: checkins.length,
      });
      const activeAppts = appointments.filter(a => a.status !== 'cancelado');
      const sorted = [...activeAppts].sort((a, b) => a.slot_start.localeCompare(b.slot_start));
      setRecentAppointments(sorted.slice(0, 20));
      const allNotices = await base44.entities.Notice.filter({ active: true });
      setNotices(allNotices.filter(n => !n.target_roles || n.target_roles.length === 0 || n.target_roles.includes(role)));
      if (role === 'aluno') {
        const session = JSON.parse(localStorage.getItem('studentSession') || 'null');
        if (session?.student_id) {
          const studs = await base44.entities.Student.filter({ id: session.student_id });
          setMyStudent(studs[0] || null);
        } else if (user?.id) {
          const studs = await base44.entities.Student.filter({ user_id: user.id });
          setMyStudent(studs[0] || null);
        }
      }
    };
    load();
  }, [role]);

  const NoticesList = () => {
    if (notices.length === 0) return null;
    return (
      <div className="space-y-3">
        {notices.map(n => {
          const styles = {
            info: { bg: 'bg-blue-500/10 border-blue-500/30', icon: Bell, iconColor: 'text-blue-400', titleColor: 'text-blue-300' },
            warning: { bg: 'bg-yellow-500/10 border-yellow-500/30', icon: AlertTriangle, iconColor: 'text-yellow-400', titleColor: 'text-yellow-300' },
            success: { bg: 'bg-primary/10 border-primary/30', icon: Star, iconColor: 'text-primary', titleColor: 'text-primary' },
          }[n.type] || { bg: 'bg-blue-500/10 border-blue-500/30', icon: Bell, iconColor: 'text-blue-400', titleColor: 'text-blue-300' };
          const Icon = styles.icon;
          return (
            <div key={n.id} className={`border rounded-xl p-4 flex gap-3 ${styles.bg}`}>
              <Icon className={`w-5 h-5 flex-shrink-0 mt-0.5 ${styles.iconColor}`} />
              <div>
                <p className={`font-semibold text-sm ${styles.titleColor}`}>{n.title}</p>
                <p className="text-sm text-muted-foreground mt-0.5">{n.content}</p>
              </div>
            </div>
          );
        })}
      </div>
    );
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Dashboard</h1>
        <p className="text-muted-foreground text-sm mt-1">
          {format(new Date(), "EEEE, dd 'de' MMMM 'de' yyyy", { locale: ptBR })}
        </p>
      </div>

      {['admin', 'gerente', 'recepcao'].includes(role) && (
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <StatCard icon={Users} label="Alunos Ativos" value={stats.students} />
          <StatCard icon={Calendar} label="Agendamentos Hoje" value={stats.todayAppointments} />
          <StatCard icon={UserCheck} label="Check-ins Hoje" value={stats.todayCheckins} />
        </div>
      )}

      {['admin', 'gerente', 'recepcao', 'professor'].includes(role) && (
        <StudentsOvertime />
      )}

      {/* Informativos — visíveis para todos os perfis, acima da agenda */}
      <NoticesList />

      {['admin', 'gerente', 'recepcao', 'professor'].includes(role) && (
        <div className="bg-card border border-border rounded-xl">
          <div className="px-5 py-4 border-b border-border">
            <h2 className="font-semibold text-foreground flex items-center gap-2">
              <Clock className="w-4 h-4 text-primary" />
              Agendamentos de Hoje
            </h2>
          </div>
          <div className="p-5">
            {recentAppointments.length === 0 ? (
              <p className="text-muted-foreground text-sm text-center py-8">Nenhum agendamento para hoje.</p>
            ) : (
              <div className="space-y-2">
                {recentAppointments.map(a => (
                  <div key={a.id} className="flex items-center justify-between py-2 border-b border-border/50 last:border-0">
                    <div>
                      <p className="text-sm font-medium text-foreground">{a.student_name}</p>
                      <p className="text-xs text-muted-foreground">{a.slot_start} – {a.slot_end}</p>
                    </div>
                    <span className={`text-xs px-2 py-1 rounded-full font-medium ${
                      a.status === 'confirmado' ? 'bg-primary/20 text-primary' :
                      a.status === 'cancelado' ? 'bg-destructive/20 text-destructive' :
                      'bg-muted text-muted-foreground'
                    }`}>
                      {a.status}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {role === 'aluno' && myStudent && (() => {
        const atestadoDate = myStudent.atestado_data ? addYears(parseISO(myStudent.atestado_data), 1) : null;
        const daysUntilExpiry = atestadoDate ? differenceInDays(atestadoDate, new Date()) : null;
        if (daysUntilExpiry === null || daysUntilExpiry > 30) return null;
        return (
          <div className={`border rounded-xl p-4 flex gap-3 ${daysUntilExpiry < 0 ? 'bg-destructive/10 border-destructive/30' : 'bg-yellow-500/10 border-yellow-500/30'}`}>
            <AlertTriangle className={`w-5 h-5 flex-shrink-0 mt-0.5 ${daysUntilExpiry < 0 ? 'text-destructive' : 'text-yellow-400'}`} />
            <div>
              <p className={`font-semibold text-sm ${daysUntilExpiry < 0 ? 'text-destructive' : 'text-yellow-300'}`}>
                {daysUntilExpiry < 0 ? 'Atestado médico vencido!' : 'Atestado médico próximo do vencimento'}
              </p>
              <p className="text-sm text-muted-foreground mt-0.5">
                {daysUntilExpiry < 0
                  ? `Venceu em ${format(atestadoDate, 'dd/MM/yyyy')}. Procure a recepção para renová-lo.`
                  : `Vence em ${format(atestadoDate, 'dd/MM/yyyy')} (${daysUntilExpiry} dia${daysUntilExpiry !== 1 ? 's' : ''}). Procure a recepção para renová-lo.`
                }
              </p>
            </div>
          </div>
        );
      })()}

      {role === 'aluno' && (
        <div className="bg-card border border-border rounded-xl p-6 text-center">
          <Dumbbell className="w-12 h-12 text-primary mx-auto mb-3" />
          <h2 className="text-lg font-semibold text-foreground mb-1">Bem-vindo à Academia SECAMI!</h2>
          <p className="text-muted-foreground text-sm">Use o menu para ver seu treino, agendar horários e acompanhar seu histórico.</p>
        </div>
      )}
    </div>
  );
}