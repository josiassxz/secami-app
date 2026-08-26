import { useState, useEffect, useMemo } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';
import { Activity, Filter, X, FileSpreadsheet } from 'lucide-react';
import * as XLSX from 'xlsx';
import { format, subDays } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const STATUS_OPTIONS = [
  { value: '', label: 'Todos os status' },
  { value: 'checkin', label: 'Check-in realizado' },
  { value: 'faltou', label: 'Falta' },
  { value: 'agendado', label: 'Agendado' },
  { value: 'confirmado', label: 'Confirmado' },
  { value: 'cancelado', label: 'Cancelado' },
];

const STATUS_STYLE = {
  checkin:   { label: 'Check-in',  cls: 'bg-primary/20 text-primary' },
  faltou:    { label: 'Falta',     cls: 'bg-destructive/20 text-destructive' },
  cancelado: { label: 'Cancelado', cls: 'bg-destructive/20 text-destructive' },
  confirmado:{ label: 'Confirmado',cls: 'bg-primary/20 text-primary' },
  agendado:  { label: 'Agendado',  cls: 'bg-muted text-muted-foreground' },
};

export default function Reports() {
  const { user } = useAuth();
  const role = user?.role;

  const [checkins, setCheckins] = useState([]);
  const [appointments, setAppointments] = useState([]);
  const [students, setStudents] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filters
  const defaultStart = format(subDays(new Date(), 29), 'yyyy-MM-dd');
  const defaultEnd   = format(new Date(), 'yyyy-MM-dd');
  const [startDate, setStartDate] = useState(defaultStart);
  const [endDate,   setEndDate]   = useState(defaultEnd);
  const [statusFilter, setStatusFilter] = useState('');
  const [cpfFilter, setCpfFilter] = useState(''); // only digits

  const formatCPF = (value) => {
    const digits = value.replace(/\D/g, '').slice(0, 11);
    return digits
      .replace(/^(\d{3})(\d)/, '$1.$2')
      .replace(/^(\d{3})\.(\d{3})(\d)/, '$1.$2.$3')
      .replace(/\.(\d{3})(\d)/, '.$1-$2');
  };

  const handleCpfChange = (e) => {
    const raw = e.target.value.replace(/\D/g, '').slice(0, 11);
    setCpfFilter(raw);
  };

  useEffect(() => {
    const load = async () => {
      setLoading(true);
      const [cins, appts, studs] = await Promise.all([
        base44.entities.CheckIn.list('-date', 1000),
        base44.entities.Appointment.list('-date', 1000),
        base44.entities.Student.list(),
      ]);
      setCheckins(cins);
      setAppointments(appts);
      setStudents(studs);
      setLoading(false);
    };
    load();
  }, []);

  // Last 7 days chart (always static, ignores filters)
  const last7 = Array.from({ length: 7 }, (_, i) => {
    const d     = format(subDays(new Date(), 6 - i), 'yyyy-MM-dd');
    const label = format(subDays(new Date(), 6 - i), 'dd/MM');
    return { label, count: checkins.filter(c => c.date === d).length };
  });

  // Build unified rows for the table
  const rows = useMemo(() => {
    const result = [];

    // appointments in date range
    const appts = appointments.filter(a => a.date >= startDate && a.date <= endDate && a.status !== 'cancelado');

    for (const appt of appts) {
      const ck = checkins.find(c => c.appointment_id === appt.id || (c.student_id === appt.student_id && c.date === appt.date));
      const rowStatus = ck ? 'checkin' : appt.status; // 'faltou', 'agendado', 'confirmado'
      result.push({
        id:           appt.id,
        date:         appt.date,
        student_id:   appt.student_id,
        student_name: appt.student_name || '–',
        student_type: appt.student_type || '–',
        slot_start:   appt.slot_start,
        slot_end:     appt.slot_end,
        check_in_time: ck?.check_in_time || '–',
        check_out_time: ck?.check_out_time || '–',
        status:       rowStatus,
      });
    }

    // cancelled appointments in range
    const cancelled = appointments.filter(a => a.date >= startDate && a.date <= endDate && a.status === 'cancelado');
    for (const appt of cancelled) {
      result.push({
        id:           appt.id + '_c',
        date:         appt.date,
        student_id:   appt.student_id,
        student_name: appt.student_name || '–',
        student_type: appt.student_type || '–',
        slot_start:   appt.slot_start,
        slot_end:     appt.slot_end,
        check_in_time: '–',
        check_out_time: '–',
        status: 'cancelado',
      });
    }

    // Apply status filter
    let filtered = statusFilter ? result.filter(r => r.status === statusFilter) : result;

    // Apply CPF filter
    if (cpfFilter) {
      const studentCpfMap = {};
      students.forEach(s => { studentCpfMap[s.id] = (s.cpf || '').replace(/\D/g, ''); });
      filtered = filtered.filter(r => {
        const cpf = studentCpfMap[r.student_id] || '';
        return cpf.includes(cpfFilter);
      });
    }

    // Sort by date desc then slot_start
    return filtered.sort((a, b) => a.date < b.date ? 1 : a.date > b.date ? -1 : a.slot_start < b.slot_start ? -1 : 1);
  }, [appointments, checkins, startDate, endDate, statusFilter, cpfFilter, students]);

  const civil = students.filter(s => s.student_type === 'Civil').length;
  const outro = students.filter(s => s.student_type !== 'Civil').length;

  const handleExportExcel = () => {
    const data = rows.map(r => ({
      Data: new Date(r.date + 'T12:00:00').toLocaleDateString('pt-BR'),
      Aluno: r.student_name,
      Tipo: r.student_type,
      Horário: `${r.slot_start} – ${r.slot_end}`,
      'Check-in': r.check_in_time,
      'Check-out': r.check_out_time,
      Status: (STATUS_STYLE[r.status] || { label: r.status }).label,
    }));
    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Relatório');
    XLSX.writeFile(wb, `relatorio_${startDate}_a_${endDate}.xlsx`);
  };

  const clearFilters = () => { setStartDate(defaultStart); setEndDate(defaultEnd); setStatusFilter(''); setCpfFilter(''); };

  if (!['admin', 'gerente'].includes(role)) {
    return <div className="text-center py-20 text-muted-foreground">Acesso restrito.</div>;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-foreground flex items-center gap-2">
          <Activity className="w-6 h-6 text-primary" />
          Relatórios
        </h1>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
        <div className="bg-card border border-border rounded-xl p-4 text-center">
          <p className="text-3xl font-bold text-primary">{students.length}</p>
          <p className="text-xs text-muted-foreground mt-1">Total Alunos</p>
        </div>
        <div className="bg-card border border-border rounded-xl p-4 text-center">
          <p className="text-3xl font-bold text-blue-400">{civil}</p>
          <p className="text-xs text-muted-foreground mt-1">Civis</p>
        </div>
        <div className="bg-card border border-border rounded-xl p-4 text-center">
          <p className="text-3xl font-bold text-orange-400">{outro}</p>
          <p className="text-xs text-muted-foreground mt-1">Militares/Outros</p>
        </div>
        <div className="bg-card border border-border rounded-xl p-4 text-center">
          <p className="text-3xl font-bold text-primary">{checkins.filter(c => c.date === format(new Date(), 'yyyy-MM-dd')).length}</p>
          <p className="text-xs text-muted-foreground mt-1">Check-ins Hoje</p>
        </div>
      </div>

      {/* Chart */}
      <div className="bg-card border border-border rounded-xl p-5">
        <h2 className="font-semibold text-foreground mb-4">Check-ins (últimos 7 dias)</h2>
        <ResponsiveContainer width="100%" height={200}>
          <BarChart data={last7}>
            <XAxis dataKey="label" tick={{ fill: '#6b7280', fontSize: 12 }} axisLine={false} tickLine={false} />
            <YAxis tick={{ fill: '#6b7280', fontSize: 12 }} axisLine={false} tickLine={false} allowDecimals={false} />
            <Tooltip contentStyle={{ backgroundColor: '#1a1f2e', border: '1px solid #2d3444', borderRadius: 8, color: '#f0f0f0' }} />
            <Bar dataKey="count" fill="hsl(82, 70%, 50%)" radius={[4, 4, 0, 0]} name="Check-ins" />
          </BarChart>
        </ResponsiveContainer>
      </div>

      {/* Filters + Table */}
      <div className="bg-card border border-border rounded-xl p-5 space-y-4">
        <div className="flex items-center gap-2 flex-wrap">
          <Filter className="w-4 h-4 text-muted-foreground flex-shrink-0" />
          <span className="text-sm font-semibold text-foreground mr-1">Filtros</span>

          <div className="flex items-center gap-1.5">
            <label className="text-xs text-muted-foreground">De</label>
            <input
              type="date"
              value={startDate}
              onChange={e => setStartDate(e.target.value)}
              className="bg-background border border-border rounded-lg px-2 py-1.5 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>
          <div className="flex items-center gap-1.5">
            <label className="text-xs text-muted-foreground">Até</label>
            <input
              type="date"
              value={endDate}
              onChange={e => setEndDate(e.target.value)}
              className="bg-background border border-border rounded-lg px-2 py-1.5 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-ring"
            />
          </div>

          <select
            value={statusFilter}
            onChange={e => setStatusFilter(e.target.value)}
            className="bg-background border border-border rounded-lg px-2 py-1.5 text-xs text-foreground focus:outline-none focus:ring-2 focus:ring-ring"
          >
            {STATUS_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
          </select>

          <input
            type="text"
            value={formatCPF(cpfFilter)}
            onChange={handleCpfChange}
            placeholder="CPF"
            className="bg-background border border-border rounded-lg px-2 py-1.5 text-xs text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring w-32"
          />

          {(statusFilter || cpfFilter || startDate !== defaultStart || endDate !== defaultEnd) && (
            <button onClick={clearFilters} className="flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground border border-border px-2 py-1.5 rounded-lg hover:bg-muted/30 transition-colors">
              <X className="w-3 h-3" /> Limpar
            </button>
          )}

          <button
            onClick={handleExportExcel}
            disabled={rows.length === 0}
            className="flex items-center gap-1.5 ml-auto text-xs bg-primary/10 text-primary hover:bg-primary/20 border border-primary/30 px-3 py-1.5 rounded-lg transition-colors font-medium disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <FileSpreadsheet className="w-3.5 h-3.5" /> Exportar para Excel
          </button>

          <span className="text-xs text-muted-foreground">{rows.length} registro(s)</span>
        </div>

        {loading ? (
          <div className="flex justify-center py-8">
            <div className="w-5 h-5 border-2 border-primary border-t-transparent rounded-full animate-spin" />
          </div>
        ) : rows.length === 0 ? (
          <div className="text-center py-10 text-muted-foreground text-sm">Nenhum registro encontrado para os filtros selecionados.</div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border text-left">
                  <th className="pb-2 text-xs font-medium text-muted-foreground">Data</th>
                  <th className="pb-2 text-xs font-medium text-muted-foreground">Aluno</th>
                  <th className="pb-2 text-xs font-medium text-muted-foreground hidden sm:table-cell">Tipo</th>
                  <th className="pb-2 text-xs font-medium text-muted-foreground hidden sm:table-cell">Horário</th>
                  <th className="pb-2 text-xs font-medium text-muted-foreground hidden md:table-cell">Check-in</th>
                  <th className="pb-2 text-xs font-medium text-muted-foreground hidden md:table-cell">Check-out</th>
                  <th className="pb-2 text-xs font-medium text-muted-foreground">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {rows.map(r => {
                  const s = STATUS_STYLE[r.status] || { label: r.status, cls: 'bg-muted text-muted-foreground' };
                  return (
                    <tr key={r.id} className="hover:bg-muted/10 transition-colors">
                      <td className="py-2.5 pr-3 text-foreground whitespace-nowrap">
                        {new Date(r.date + 'T12:00:00').toLocaleDateString('pt-BR')}
                      </td>
                      <td className="py-2.5 pr-3 text-foreground font-medium">{r.student_name}</td>
                      <td className="py-2.5 pr-3 text-muted-foreground hidden sm:table-cell">{r.student_type}</td>
                      <td className="py-2.5 pr-3 text-muted-foreground hidden sm:table-cell whitespace-nowrap">{r.slot_start} – {r.slot_end}</td>
                      <td className="py-2.5 pr-3 text-muted-foreground hidden md:table-cell">{r.check_in_time}</td>
                      <td className="py-2.5 pr-3 text-muted-foreground hidden md:table-cell">{r.check_out_time}</td>
                      <td className="py-2.5">
                        <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${s.cls}`}>{s.label}</span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}