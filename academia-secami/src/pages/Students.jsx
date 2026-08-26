import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Plus, Search, User, Edit, Trash2, X } from 'lucide-react';
import StudentForm from '../components/StudentForm';
import StudentProfileModal from '../components/StudentProfileModal';
import StudentViewModal from '../components/StudentViewModal';

const maskCPF = (cpf) => {
  if (!cpf) return '–';
  const digits = cpf.replace(/\D/g, '');
  if (digits.length !== 11) return cpf;
  return `${digits.slice(0,3)}.***.***-${digits.slice(9)}`;
};

export default function Students() {
  const { user } = useAuth();
  const [students, setStudents] = useState([]);
  const [search, setSearch] = useState('');
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState(null);
  const [loading, setLoading] = useState(true);

  const role = user?.role;
  const canEdit = ['admin', 'gerente'].includes(role);
  const isStaff = ['admin', 'gerente', 'recepcao', 'professor'].includes(role);
  const [myStudent, setMyStudent] = useState(null);
  const [showProfileModal, setShowProfileModal] = useState(false);
  const [viewingStudent, setViewingStudent] = useState(null);
  const [photoModal, setPhotoModal] = useState(null); // { name, photo_url }

  const load = async () => {
    setLoading(true);
    if (!isStaff) {
      const mine = await base44.entities.Student.filter({ user_id: user?.id });
      setMyStudent(mine[0] || null);
      setStudents(mine[0] ? [mine[0]] : []);
    } else {
      const data = await base44.entities.Student.list('-created_date', 1000);
      setStudents(data);
    }
    setLoading(false);
  };

  useEffect(() => { load(); }, []);

  const handleDelete = async (id) => {
    if (!confirm('Excluir este aluno?')) return;
    await base44.entities.Student.delete(id);
    load();
  };

  const searchDigits = search.replace(/\D/g, '');
  const filtered = (!isStaff ? students.filter(s => s.id === myStudent?.id) : students).filter(s =>
    s.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    (searchDigits && (s.cpf || '').replace(/\D/g, '').includes(searchDigits))
  );

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Alunos</h1>
          <p className="text-muted-foreground text-sm">{students.length} alunos cadastrados</p>
        </div>
        {!isStaff && myStudent && (
          <button
            onClick={() => setShowProfileModal(true)}
            className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Edit className="w-4 h-4" /> Editar Meu Perfil
          </button>
        )}
        {canEdit && (
          <button
            onClick={() => { setEditing(null); setShowForm(true); }}
            className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-lg text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Plus className="w-4 h-4" /> Novo Aluno
          </button>
        )}
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <input
          value={search}
          onChange={e => setSearch(e.target.value)}
          placeholder="Buscar por nome ou CPF..."
          className="w-full bg-card border border-border rounded-lg pl-10 pr-4 py-2.5 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-ring"
        />
      </div>

      {loading ? (
        <div className="flex justify-center py-12">
          <div className="w-6 h-6 border-2 border-primary border-t-transparent rounded-full animate-spin" />
        </div>
      ) : (
        <div className="bg-card border border-border rounded-xl overflow-hidden">
          {filtered.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              <User className="w-10 h-10 mx-auto mb-3 opacity-30" />
              <p>Nenhum aluno encontrado</p>
            </div>
          ) : (
            <div className="divide-y divide-border">
              {filtered.map(s => (
                <div key={s.id} className="flex items-center gap-3 px-5 py-3 hover:bg-muted/30 transition-colors">
                  <button
                    onClick={() => s.photo_url && setPhotoModal({ name: s.full_name, photo_url: s.photo_url })}
                    className={`w-9 h-9 rounded-full flex-shrink-0 overflow-hidden border-2 ${s.photo_url ? 'border-primary/40 hover:border-primary cursor-pointer' : 'border-transparent cursor-default'}`}
                  >
                    {s.photo_url ? (
                      <img src={s.photo_url} alt={s.full_name} className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-full h-full bg-primary/20 flex items-center justify-center text-primary font-semibold text-sm">
                        {s.full_name?.[0]?.toUpperCase()}
                      </div>
                    )}
                  </button>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <p className="font-medium text-foreground text-sm truncate">{s.full_name}</p>
                      <span className={`text-xs px-2 py-0.5 rounded-full font-medium flex-shrink-0 ${
                        s.student_type === 'Civil' ? 'bg-blue-500/20 text-blue-400' : 'bg-orange-500/20 text-orange-400'
                      }`}>
                        {s.student_type}
                      </span>
                    </div>
                    <p className="text-xs text-muted-foreground">{maskCPF(s.cpf)} · {s.goal}</p>
                  </div>
                  {role === 'professor' && (
                    <button
                      onClick={() => setViewingStudent(s)}
                      className="p-1.5 rounded-lg text-muted-foreground hover:text-primary hover:bg-primary/10 transition-colors"
                    >
                      <User className="w-4 h-4" />
                    </button>
                  )}
                  {canEdit && (
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => { setEditing(s); setShowForm(true); }}
                        className="p-1.5 rounded-lg text-muted-foreground hover:text-primary hover:bg-primary/10 transition-colors"
                      >
                        <Edit className="w-4 h-4" />
                      </button>
                      {role === 'admin' && (
                        <button
                          onClick={() => handleDelete(s.id)}
                          className="p-1.5 rounded-lg text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}
        </div>
      )}

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

      {viewingStudent && (
        <StudentViewModal student={viewingStudent} onClose={() => setViewingStudent(null)} />
      )}

      {showProfileModal && myStudent && (
        <StudentProfileModal
          student={myStudent}
          onSave={() => { setShowProfileModal(false); base44.entities.Student.filter({ user_id: user?.id }).then(r => setMyStudent(r[0] || null)); }}
          onClose={() => setShowProfileModal(false)}
        />
      )}

      {showForm && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between px-6 py-4 border-b border-border">
              <h2 className="font-semibold text-foreground">{editing ? 'Editar Aluno' : 'Novo Aluno'}</h2>
              <button onClick={() => setShowForm(false)} className="text-muted-foreground hover:text-foreground">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="p-6">
              <StudentForm
                initial={editing}
                onSave={() => { setShowForm(false); load(); }}
                onCancel={() => setShowForm(false)}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}