import { useState, useEffect } from 'react';
import { base44 } from '@/api/base44Client';
import { useAuth } from '@/lib/AuthContext';
import { Dumbbell, CheckCircle, Circle, Trophy, Info, Eye, X, Video } from 'lucide-react';
import { format } from 'date-fns';

export default function MyWorkout() {
  const { user } = useAuth();
  const [student, setStudent] = useState(null);
  const [plans, setPlans] = useState([]);
  const [activeSheet, setActiveSheet] = useState('A');
  const [log, setLog] = useState(null);
  const [completed, setCompleted] = useState([]);
  const [saving, setSaving] = useState(false);
  const [loadModal, setLoadModal] = useState(null); // { exerciseName }
  const [loadInput, setLoadInput] = useState('');
  const [loads, setLoads] = useState([]); // [{ exercise_name, load }]
  const [exercises, setExercises] = useState([]);
  const [viewExercise, setViewExercise] = useState(null);
  const today = format(new Date(), 'yyyy-MM-dd');

  useEffect(() => {
    const load = async () => {
      const students = await base44.entities.Student.filter({ user_id: user?.id });
      const myStudent = students[0];
      setStudent(myStudent);
      if (myStudent) {
        const [p, logs, exs] = await Promise.all([
          base44.entities.WorkoutPlan.filter({ student_id: myStudent.id }),
          base44.entities.WorkoutLog.filter({ student_id: myStudent.id, date: today }),
          base44.entities.Exercise.list(),
        ]);
        setPlans(p);
        setExercises(exs);
        const todayLog = logs[0];
        if (todayLog) {
          setLog(todayLog);
          setCompleted(todayLog.completed_exercises || []);
          setLoads(todayLog.exercise_loads || []);
          setActiveSheet(todayLog.sheet_label || 'A');
        }
      }
    };
    load();
  }, []);

  const currentPlan = plans.find(p => p.sheet_label === activeSheet && p.active !== false);

  const handleExerciseClick = (exerciseName) => {
    if (completed.includes(exerciseName)) {
      // Desmarcar direto
      confirmExercise(exerciseName, null, true);
    } else {
      setLoadInput('');
      setLoadModal({ exerciseName });
    }
  };

  const confirmExercise = async (exerciseName, load, removing = false) => {
    setLoadModal(null);
    const newCompleted = removing
      ? completed.filter(e => e !== exerciseName)
      : [...completed, exerciseName];

    let newLoads = loads.filter(l => l.exercise_name !== exerciseName);
    if (!removing && load) {
      newLoads = [...newLoads, { exercise_name: exerciseName, load }];
    }

    setCompleted(newCompleted);
    setLoads(newLoads);

    const allDone = currentPlan?.exercises?.length === newCompleted.length;

    if (log?.id) {
      await base44.entities.WorkoutLog.update(log.id, { completed_exercises: newCompleted, exercise_loads: newLoads, completed: allDone });
    } else {
      const created = await base44.entities.WorkoutLog.create({
        student_id: student.id,
        workout_plan_id: currentPlan?.id || '',
        sheet_label: activeSheet,
        date: today,
        completed_exercises: newCompleted,
        exercise_loads: newLoads,
        completed: allDone,
      });
      setLog(created);
    }
  };

  const labels = [...new Set(plans.map(p => p.sheet_label))].sort();

  if (!student) {
    return (
      <div className="text-center py-20">
        <Dumbbell className="w-12 h-12 mx-auto mb-3 text-muted-foreground opacity-30" />
        <p className="text-muted-foreground">Seu perfil de aluno ainda não foi configurado.</p>
        <p className="text-xs text-muted-foreground mt-1">Fale com a recepção.</p>
      </div>
    );
  }

  const allDone = currentPlan?.exercises?.length > 0 && completed.length === currentPlan.exercises.length;

  return (
    <div className="space-y-5">
      <div>
        <h1 className="text-2xl font-bold text-foreground">Meu Treino</h1>
        <p className="text-muted-foreground text-sm">{today}</p>
      </div>

      <div className="bg-blue-500/10 border border-blue-500/20 rounded-xl p-3 flex items-start gap-2.5">
        <Info className="w-4 h-4 text-blue-400 flex-shrink-0 mt-0.5" />
        <p className="text-xs text-blue-300 leading-relaxed">
          O progresso do treino é registrado por dia. Ao marcar os exercícios, seu registro de hoje é salvo automaticamente. Amanhã a ficha começa zerada.
        </p>
      </div>

      {labels.length > 0 && (
        <div className="flex gap-2">
          {labels.map(l => (
            <button
              key={l}
              onClick={() => { setActiveSheet(l); setCompleted([]); }}
              className={`w-12 h-12 rounded-xl font-bold text-lg transition-colors ${
                activeSheet === l ? 'bg-primary text-primary-foreground' : 'bg-card border border-border text-muted-foreground hover:border-primary/50'
              }`}
            >
              {l}
            </button>
          ))}
        </div>
      )}

      {allDone && (
        <div className="bg-primary/10 border border-primary/30 rounded-xl p-4 flex items-center gap-3">
          <Trophy className="w-6 h-6 text-primary" />
          <div>
            <p className="font-semibold text-primary">Treino Concluído! 🎉</p>
            <p className="text-xs text-muted-foreground">Excelente trabalho! Continue assim.</p>
          </div>
        </div>
      )}

      {currentPlan ? (
        <div className="bg-card border border-border rounded-xl overflow-hidden">
          <div className="px-5 py-4 border-b border-border">
            <p className="font-semibold text-foreground">{currentPlan.title}</p>
            <p className="text-xs text-muted-foreground mt-0.5">{completed.length}/{currentPlan.exercises?.length || 0} exercícios concluídos</p>
            {currentPlan.professor_name && (
              <p className="text-xs text-muted-foreground mt-1">Criado por: <span className="text-foreground">{currentPlan.professor_name}</span></p>
            )}
          </div>
          <div className="divide-y divide-border">
            {currentPlan.exercises?.map((ex, i) => {
              const done = completed.includes(ex.exercise_name);
              return (
                <div key={i} className={`flex items-center gap-3 px-5 py-4 border-0 transition-colors hover:bg-muted/10 ${done ? 'opacity-60' : ''}`}>
                  <button onClick={() => handleExerciseClick(ex.exercise_name)} className="flex items-center gap-4 flex-1 text-left">
                    {done ? <CheckCircle className="w-5 h-5 text-primary flex-shrink-0" /> : <Circle className="w-5 h-5 text-muted-foreground flex-shrink-0" />}
                    <div className="flex-1">
                      <p className={`font-medium text-sm ${done ? 'line-through text-muted-foreground' : 'text-foreground'}`}>{ex.exercise_name}</p>
                      <p className="text-xs text-muted-foreground">{ex.sets}x {ex.reps} · {ex.rest_seconds}s descanso</p>
                      {done && loads.find(l => l.exercise_name === ex.exercise_name)?.load && (
                        <p className="text-xs text-primary mt-0.5">Carga: {loads.find(l => l.exercise_name === ex.exercise_name).load}</p>
                      )}
                    </div>
                  </button>
                  <button
                    onClick={() => setViewExercise(exercises.find(e => e.name === ex.exercise_name) || { name: ex.exercise_name })}
                    className="p-2 text-muted-foreground hover:text-primary hover:bg-primary/10 rounded-lg transition-colors flex-shrink-0"
                    title="Ver detalhes"
                  >
                    <Eye className="w-4 h-4" />
                  </button>
                </div>
              );
            })}
          </div>
        </div>
      ) : (
        <div className="text-center py-12 bg-card border border-border rounded-xl">
          <Dumbbell className="w-10 h-10 mx-auto mb-3 text-muted-foreground opacity-30" />
          <p className="text-muted-foreground">Nenhuma ficha {activeSheet} ativa encontrada.</p>
        </div>
      )}

      {viewExercise && (
        <div className="fixed inset-0 bg-black/70 z-50 flex items-end sm:items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-sm overflow-hidden">
            {viewExercise.photo_url && (
              <img src={viewExercise.photo_url} alt={viewExercise.name} className="w-full max-h-64 object-contain bg-black/30" />
            )}
            <div className="p-5 space-y-3">
              <div className="flex items-start justify-between">
                <div>
                  <p className="font-semibold text-foreground">{viewExercise.name}</p>
                  {viewExercise.muscle_group && <span className="text-xs px-2 py-0.5 rounded-full bg-primary/20 text-primary mt-1 inline-block">{viewExercise.muscle_group}</span>}
                </div>
                <button onClick={() => setViewExercise(null)} className="p-1 text-muted-foreground hover:text-foreground">
                  <X className="w-5 h-5" />
                </button>
              </div>
              {viewExercise.equipment && <p className="text-xs text-muted-foreground">🏋️ {viewExercise.equipment}</p>}
              {viewExercise.description && <p className="text-sm text-muted-foreground leading-relaxed">{viewExercise.description}</p>}
              {viewExercise.video_url && (
                <a href={viewExercise.video_url} target="_blank" rel="noopener noreferrer"
                  className="flex items-center gap-2 bg-primary/10 border border-primary/20 text-primary rounded-lg px-4 py-2.5 text-sm font-medium hover:bg-primary/20 transition-colors">
                  <Video className="w-4 h-4" /> Ver vídeo demonstrativo
                </a>
              )}
              <button onClick={() => setViewExercise(null)} className="w-full py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">
                Fechar
              </button>
            </div>
          </div>
        </div>
      )}

      {loadModal && (
        <div className="fixed inset-0 bg-black/60 z-50 flex items-end sm:items-center justify-center p-4">
          <div className="bg-card border border-border rounded-2xl w-full max-w-sm p-5 space-y-4">
            <div>
              <p className="font-semibold text-foreground text-sm">{loadModal.exerciseName}</p>
              <p className="text-xs text-muted-foreground mt-0.5">Qual foi a carga utilizada?</p>
            </div>
            <input
              autoFocus
              type="text"
              inputMode="decimal"
              placeholder="Ex: 20kg, 15kg cada, peso corporal..."
              value={loadInput}
              onChange={e => setLoadInput(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && confirmExercise(loadModal.exerciseName, loadInput)}
              className="w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring"
            />
            <div className="flex gap-3">
              <button
                onClick={() => confirmExercise(loadModal.exerciseName, loadInput)}
                className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90"
              >
                Confirmar
              </button>
              <button
                onClick={() => setLoadModal(null)}
                className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30"
              >
                Cancelar
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}