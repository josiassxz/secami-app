package br.gov.goias.secami.training.log;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.training.log.WorkoutLogDtos.ExerciseEntry;
import br.gov.goias.secami.training.log.WorkoutLogDtos.UpsertRequest;
import br.gov.goias.secami.training.plan.WorkoutPlan;
import br.gov.goias.secami.training.plan.WorkoutPlanRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Execução da ficha pelo aluno: marca exercícios feitos (com carga) no dia.
 * Mesma semântica do legado (MyWorkout.jsx): 1 log por (aluno, data);
 * completo quando a contagem de exercícios marcados atinge a da ficha.
 */
@Service
public class WorkoutLogService {

    private final WorkoutLogRepository logs;
    private final StudentRepository students;
    private final WorkoutPlanRepository plans;

    public WorkoutLogService(WorkoutLogRepository logs, StudentRepository students,
                             WorkoutPlanRepository plans) {
        this.logs = logs;
        this.students = students;
        this.plans = plans;
    }

    @Transactional(readOnly = true)
    public Optional<WorkoutLog> today(UUID userId, LocalDate date) {
        Student s = requireStudent(userId);
        return logs.findByStudentIdAndDate(s.getId(), date);
    }

    @Transactional(readOnly = true)
    public List<WorkoutLog> history(UUID userId) {
        Student s = requireStudent(userId);
        return logs.findByStudent(s.getId());
    }

    @Transactional
    public WorkoutLog upsert(UUID userId, UpsertRequest req) {
        Student student = requireStudent(userId);
        WorkoutLog log = logs.findByStudentIdAndDate(student.getId(), req.date())
                .orElseGet(WorkoutLog::new);
        log.setStudent(student);
        log.setDate(req.date());
        log.setWorkoutPlanId(req.workoutPlanId());
        log.setSheetLabel(req.sheetLabel());

        log.getExercises().clear();
        List<ExerciseEntry> entries = req.exercises() == null ? List.of() : req.exercises();
        for (ExerciseEntry entry : entries) {
            WorkoutLogExercise wle = new WorkoutLogExercise();
            wle.setExerciseName(entry.exerciseName());
            wle.setLoad(entry.load());
            wle.setCompleted(true);
            log.addExercise(wle);
        }

        int totalDaFicha = req.workoutPlanId() == null ? entries.size()
                : plans.findByIdAndDeletedAtIsNull(req.workoutPlanId())
                        .map(WorkoutPlan::getExercises).map(List::size).orElse(entries.size());
        log.setCompleted(!entries.isEmpty() && entries.size() >= totalDaFicha);

        return logs.save(log);
    }

    private Student requireStudent(UUID userId) {
        return students.findByUserId(userId)
                .orElseThrow(() -> new NotFoundException("Nenhum aluno vinculado a esta conta."));
    }
}
