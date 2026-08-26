import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { Camera, Loader2, Video } from 'lucide-react';
import WebcamCapture from './WebcamCapture';
import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { Calendar } from '@/components/ui/calendar';
import { CalendarIcon } from 'lucide-react';
import { format, parseISO } from 'date-fns';
import { ptBR } from 'date-fns/locale';

const GOALS = ['Emagrecimento', 'Hipertrofia', 'Condicionamento', 'Saúde e Bem-estar', 'Reabilitação', 'Força'];

const maskCPF = (v) => {
  const n = v.replace(/\D/g, '').slice(0, 11);
  if (n.length <= 3) return n;
  if (n.length <= 6) return `${n.slice(0,3)}.${n.slice(3)}`;
  if (n.length <= 9) return `${n.slice(0,3)}.${n.slice(3,6)}.${n.slice(6)}`;
  return `${n.slice(0,3)}.${n.slice(3,6)}.${n.slice(6,9)}-${n.slice(9)}`;
};

const maskDecimal = (v, maxInt = 3) => {
  let s = v.replace(/[^0-9,]/g, '');
  const commaIndex = s.indexOf(',');
  if (commaIndex !== -1) {
    const intPart = s.slice(0, commaIndex).slice(0, maxInt);
    const decPart = s.slice(commaIndex + 1).replace(/,/g, '').slice(0, 2);
    s = intPart + ',' + decPart;
  } else {
    s = s.slice(0, maxInt);
  }
  return s;
};

const Field = ({ label, required, children }) => (
  <div>
    <label className="block text-xs font-medium text-muted-foreground mb-1">
      {label} {required && <span className="text-destructive">*</span>}
    </label>
    {children}
  </div>
);

export default function StudentForm({ initial, onSave, onCancel }) {
  const [form, setForm] = useState({
    full_name: initial?.full_name || '',
    cpf: initial?.cpf || '',
    email: initial?.email || '',
    password: initial?.password || '',
    weight: initial?.weight ? String(initial.weight.toFixed(2)).replace('.', ',') : '',
    height: initial?.height ? String(initial.height.toFixed(2)).replace('.', ',') : '',
    goal: initial?.goal || '',
    student_type: initial?.student_type || 'Civil',
    phone: initial?.phone || '',
    birth_date: initial?.birth_date || '',
    active: initial?.active !== undefined ? initial.active : true,
    department: initial?.department || '',
    matricula: initial?.matricula || '',
    atestado_numero: initial?.atestado_numero || '',
    atestado_data: initial?.atestado_data || '',
    photo_url: initial?.photo_url || '',
  });
  const [saving, setSaving] = useState(false);
  const [birthDateInput, setBirthDateInput] = useState(initial?.birth_date ? format(parseISO(initial.birth_date), 'dd/MM/yyyy') : '');
  const [uploading, setUploading] = useState(false);
  const [showWebcam, setShowWebcam] = useState(false);
  const [users, setUsers] = useState([]);
  const [selectedUserId, setSelectedUserId] = useState(initial?.user_id || '');
  const [userSearch, setUserSearch] = useState('');
  const [showUserDropdown, setShowUserDropdown] = useState(false);

  const [departments, setDepartments] = useState([]);

  useEffect(() => {
    base44.entities.Department.list('name', 200).then(setDepartments);
  }, []);

  useEffect(() => {
    base44.functions.invoke('getUsers', {}).then(res => {
      const raw = res.data;
      const all = Array.isArray(raw) ? raw : (raw?.data || []);
      setUsers(all.filter(u => u.full_name && u.email));
    }).catch(err => console.error('getUsers error:', err));
  }, []);

  const set = (k, v) => setForm(f => ({ ...f, [k]: v }));

  const handlePhotoUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const { file_url } = await base44.integrations.Core.UploadFile({ file });
    set('photo_url', file_url);
    setUploading(false);
  };

  const handleWebcamCapture = async (dataUrl) => {
    setShowWebcam(false);
    setUploading(true);
    const blob = await (await fetch(dataUrl)).blob();
    const file = new File([blob], 'webcam.jpg', { type: 'image/jpeg' });
    const { file_url } = await base44.integrations.Core.UploadFile({ file });
    set('photo_url', file_url);
    setUploading(false);
  };

  const handleSave = async () => {
    if (uploading) return;
    if (!form.full_name || !form.cpf || !form.birth_date) {
      alert('Preencha todos os campos obrigatórios: Nome, CPF e Data de Nascimento.');
      return;
    }
    setSaving(true);
    const data = { ...form };
    if (form.weight) data.weight = parseFloat(String(form.weight).replace(',', '.')) || undefined;
    else delete data.weight;
    if (form.height) data.height = parseFloat(String(form.height).replace(',', '.')) || undefined;
    else delete data.height;
    if (selectedUserId) data.user_id = selectedUserId;
    if (initial?.id) {
      await base44.entities.Student.update(initial.id, data);
    } else {
      await base44.entities.Student.create(data);
    }
    setSaving(false);
    onSave();
  };

  const inputCls = "w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring";

  return (
    <div className="space-y-4 relative">
      {uploading && (
        <div className="fixed inset-0 bg-black/60 z-[9999] flex flex-col items-center justify-center gap-3">
          <Loader2 className="w-10 h-10 animate-spin text-primary" />
          <p className="text-sm text-white font-medium">Enviando foto, aguarde...</p>
        </div>
      )}
      {showWebcam && <WebcamCapture onCapture={handleWebcamCapture} onClose={() => setShowWebcam(false)} />}
      <Field label="Foto">
        <div className="flex items-center gap-4">
          {form.photo_url ? (
            <img src={form.photo_url} alt="foto" className="w-16 h-16 rounded-full object-cover border-2 border-primary" />
          ) : (
            <div className="w-16 h-16 rounded-full bg-muted/40 flex items-center justify-center border border-border">
              <Camera className="w-6 h-6 text-muted-foreground" />
            </div>
          )}
          <div className="flex flex-col gap-2">
            <label className="flex items-center gap-2 cursor-pointer bg-background border border-border rounded-lg px-3 py-2 text-sm text-muted-foreground hover:border-primary/50 transition-colors">
              {uploading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Camera className="w-4 h-4" />}
              {uploading ? 'Enviando...' : 'Selecionar arquivo'}
              <input type="file" accept="image/*" className="hidden" onChange={handlePhotoUpload} disabled={uploading} />
            </label>
            <button
              type="button"
              onClick={() => setShowWebcam(true)}
              disabled={uploading}
              className="flex items-center gap-2 bg-background border border-border rounded-lg px-3 py-2 text-sm text-muted-foreground hover:border-primary/50 transition-colors disabled:opacity-50"
            >
              <Video className="w-4 h-4" /> Usar webcam
            </button>
          </div>
        </div>
      </Field>

      <Field label="Nome Completo" required>
        <input className={inputCls} value={form.full_name} onChange={e => set('full_name', e.target.value)} />
      </Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="CPF" required>
          <input
            className={inputCls}
            value={form.cpf}
            onChange={e => set('cpf', maskCPF(e.target.value))}
            placeholder="000.000.000-00"
            maxLength={14}
            inputMode="numeric"
          />
        </Field>
        <Field label="Telefone">
          <input className={inputCls} value={form.phone} onChange={e => set('phone', e.target.value)} />
        </Field>
      </div>
      <Field label="Número de Matrícula">
        <input
          className={inputCls}
          value={form.matricula}
          onChange={e => set('matricula', e.target.value)}
          placeholder="Nº do crachá"
        />
        <p className="text-xs text-muted-foreground mt-1">Corresponde ao número do crachá do aluno.</p>
      </Field>
      <Field label="Secretaria / Órgão">
        <select className={inputCls} value={form.department} onChange={e => set('department', e.target.value)}>
          <option value="">Selecione...</option>
          {departments.map(d => <option key={d.id} value={d.name}>{d.name}</option>)}
        </select>
      </Field>
      <Field label="Email">
        <input type="email" className={inputCls} value={form.email} onChange={e => set('email', e.target.value)} placeholder="email@exemplo.com" />
      </Field>
      <Field label="Senha">
        <input type="password" className={inputCls} value={form.password} onChange={e => set('password', e.target.value)} placeholder="Senha de acesso" />
      </Field>
      <div className="grid grid-cols-2 gap-3">
        <Field label="Peso (kg)">
          <input
            className={inputCls}
            value={form.weight}
            onChange={e => set('weight', maskDecimal(e.target.value, 3))}
            placeholder="00,00"
            inputMode="numeric"
          />
        </Field>
        <Field label="Altura (m)">
          <input
            className={inputCls}
            value={form.height}
            onChange={e => set('height', maskDecimal(e.target.value, 1))}
            placeholder="0,00"
            inputMode="numeric"
          />
        </Field>
      </div>
      <Field label="Data de Nascimento" required>
        <div className="flex gap-2">
          <input
            className={inputCls}
            value={birthDateInput}
            onChange={e => {
              const digits = e.target.value.replace(/\D/g, '').slice(0, 8);
              let v = digits;
              if (digits.length > 2) v = digits.slice(0,2) + '/' + digits.slice(2);
              if (digits.length > 4) v = digits.slice(0,2) + '/' + digits.slice(2,4) + '/' + digits.slice(4);
              setBirthDateInput(v);
              if (digits.length === 8) {
                const iso = `${digits.slice(4)}-${digits.slice(2,4)}-${digits.slice(0,2)}`;
                set('birth_date', iso);
              } else {
                set('birth_date', '');
              }
            }}
            placeholder="dd/mm/aaaa"
            inputMode="numeric"
            maxLength={10}
          />
          <Popover>
            <PopoverTrigger asChild>
              <button type="button" className="px-3 py-2 bg-background border border-border rounded-lg hover:border-primary/50 transition-colors flex-shrink-0">
                <CalendarIcon className="w-4 h-4 text-muted-foreground" />
              </button>
            </PopoverTrigger>
            <PopoverContent className="w-auto p-0" align="end">
              <Calendar
                mode="single"
                selected={form.birth_date ? parseISO(form.birth_date) : undefined}
                onSelect={d => { set('birth_date', d ? format(d, 'yyyy-MM-dd') : ''); setBirthDateInput(d ? format(d, 'dd/MM/yyyy') : ''); }}
                locale={ptBR}
                captionLayout="dropdown-buttons"
                fromYear={1920}
                toYear={new Date().getFullYear()}
                initialFocus
                labels={{
                  labelYearDropdown: () => 'Ano',
                  labelMonthDropdown: () => 'Mês',
                }}
                classNames={{
                  dropdown: 'bg-background text-foreground border border-border rounded px-1 py-0.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring cursor-pointer',
                  caption_dropdowns: 'flex gap-2 items-center',
                }}
              />
            </PopoverContent>
          </Popover>
        </div>
      </Field>
      <Field label="Vincular Usuário da Plataforma">
        <div className="relative">
          <input
            className={inputCls}
            placeholder="Pesquisar por nome ou email..."
            value={userSearch || (selectedUserId ? (users.find(u => u.id === selectedUserId)?.full_name + ' (' + users.find(u => u.id === selectedUserId)?.email + ')') : '')}
            onChange={e => { setUserSearch(e.target.value); setSelectedUserId(''); setShowUserDropdown(true); }}
            onFocus={() => { setUserSearch(''); setShowUserDropdown(true); }}
            onBlur={() => setTimeout(() => setShowUserDropdown(false), 150)}
          />
          {showUserDropdown && (
            <div className="absolute z-20 top-full mt-1 w-full bg-card border border-border rounded-lg shadow-lg max-h-48 overflow-y-auto">
              <div
                className="px-3 py-2 text-sm text-muted-foreground hover:bg-muted/40 cursor-pointer"
                onMouseDown={() => { setSelectedUserId(''); setUserSearch(''); setShowUserDropdown(false); }}
              >
                Nenhum (criar convite por email)
              </div>
              {users
                .filter(u => {
                  const q = userSearch.toLowerCase();
                  return u.full_name?.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q);
                })
                .map(u => (
                  <div
                    key={u.id}
                    className="px-3 py-2 text-sm text-foreground hover:bg-muted/40 cursor-pointer"
                    onMouseDown={() => { setSelectedUserId(u.id); setUserSearch(''); setShowUserDropdown(false); }}
                  >
                    {u.full_name} <span className="text-muted-foreground">({u.email})</span>
                  </div>
                ))
              }
              {users.filter(u => { const q = userSearch.toLowerCase(); return u.full_name?.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q); }).length === 0 && userSearch && (
                <div className="px-3 py-2 text-sm text-muted-foreground">Nenhum usuário encontrado</div>
              )}
            </div>
          )}
        </div>
      </Field>
      <Field label="Objetivo">
        <select className={inputCls} value={form.goal} onChange={e => set('goal', e.target.value)}>
          <option value="">Selecione...</option>
          {GOALS.map(g => <option key={g} value={g}>{g}</option>)}
        </select>
      </Field>
      <Field label="Tipo de Aluno" required>
        <div className="flex gap-2">
          {['Civil', 'Militar'].map(t => (
            <button
              key={t}
              type="button"
              onClick={() => set('student_type', t)}
              className={`flex-1 py-2 rounded-lg text-sm font-medium border transition-colors ${
                form.student_type === t
                  ? 'bg-primary text-primary-foreground border-primary'
                  : 'bg-background border-border text-muted-foreground hover:border-primary/50'
              }`}
            >
              {t}
            </button>
          ))}
        </div>
      </Field>

      <div className="border border-border rounded-xl p-4 space-y-3">
        <p className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">Atestado Médico</p>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Número do Pedido">
            <input className={inputCls} value={form.atestado_numero} onChange={e => set('atestado_numero', e.target.value)} placeholder="Ex: 2024/001" />
          </Field>
          <Field label="Data do Atestado">
            <input type="date" className={inputCls} value={form.atestado_data} onChange={e => set('atestado_data', e.target.value)} />
          </Field>
        </div>
      </div>

      <div className="flex items-center gap-2">
        <input type="checkbox" id="active" checked={form.active} onChange={e => set('active', e.target.checked)} className="accent-primary" />
        <label htmlFor="active" className="text-sm text-foreground">Aluno ativo</label>
      </div>
      <div className="flex gap-3 pt-2">
        <button
          onClick={onCancel}
          className="flex-1 py-2 rounded-lg border border-border text-sm text-muted-foreground hover:bg-muted/30 transition-colors"
        >
          Cancelar
        </button>
        <button
          onClick={handleSave}
          disabled={saving || uploading}
          className="flex-1 py-2 rounded-lg bg-primary text-primary-foreground text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50"
        >
          {saving ? 'Salvando...' : 'Salvar'}
        </button>
      </div>
    </div>
  );
}