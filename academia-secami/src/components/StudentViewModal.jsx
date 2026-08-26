import { X, User } from 'lucide-react';

export default function StudentViewModal({ student, onClose }) {
  if (!student) return null;

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
      <div className="bg-card border border-border rounded-2xl w-full max-w-sm">
        <div className="flex items-center justify-between px-6 py-4 border-b border-border">
          <h2 className="font-semibold text-foreground">Perfil do Aluno</h2>
          <button onClick={onClose}><X className="w-5 h-5 text-muted-foreground" /></button>
        </div>
        <div className="p-6 space-y-5">
          {/* Photo */}
          <div className="flex justify-center">
            {student.photo_url ? (
              <img src={student.photo_url} alt={student.full_name} className="w-24 h-24 rounded-full object-cover border-2 border-border" />
            ) : (
              <div className="w-24 h-24 rounded-full bg-primary/20 flex items-center justify-center">
                <User className="w-10 h-10 text-primary" />
              </div>
            )}
          </div>

          {/* Name & type */}
          <div className="text-center">
            <p className="text-lg font-bold text-foreground">{student.full_name}</p>
            <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${
              student.student_type === 'Civil' ? 'bg-blue-500/20 text-blue-400' : 'bg-orange-500/20 text-orange-400'
            }`}>{student.student_type}</span>
          </div>

          {/* Stats */}
          <div className="grid grid-cols-2 gap-3">
            <div className="bg-muted/30 rounded-xl p-4 text-center">
              <p className="text-2xl font-bold text-foreground">{student.weight ? `${student.weight}` : '–'}</p>
              <p className="text-xs text-muted-foreground mt-0.5">Peso (kg)</p>
            </div>
            <div className="bg-muted/30 rounded-xl p-4 text-center">
              <p className="text-2xl font-bold text-foreground">{student.height ? `${student.height}` : '–'}</p>
              <p className="text-xs text-muted-foreground mt-0.5">Altura (cm)</p>
            </div>
          </div>

          {/* Goal */}
          {student.goal && (
            <div className="bg-muted/30 rounded-xl p-4">
              <p className="text-xs text-muted-foreground mb-1">Objetivo</p>
              <p className="text-sm text-foreground font-medium">{student.goal}</p>
            </div>
          )}

          {student.department && (
            <div className="bg-muted/30 rounded-xl p-4">
              <p className="text-xs text-muted-foreground mb-1">Secretaria / Órgão</p>
              <p className="text-sm text-foreground font-medium">{student.department}</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}