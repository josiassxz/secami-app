package br.gov.goias.secami.training.plan;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.training.exercise.Exercise;
import br.gov.goias.secami.training.exercise.ExerciseRepository;
import br.gov.goias.secami.training.plan.WorkoutPlanDtos.ItemRequest;
import br.gov.goias.secami.training.plan.WorkoutPlanDtos.UpsertRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Fichas de treino: professor prescreve exercícios a um aluno. SPEC §9.3 / §11.2. */
@Service
public class WorkoutPlanService {

    private final WorkoutPlanRepository plans;
    private final StudentRepository students;
    private final ExerciseRepository exercises;

    public WorkoutPlanService(WorkoutPlanRepository plans, StudentRepository students,
                              ExerciseRepository exercises) {
        this.plans = plans;
        this.students = students;
        this.exercises = exercises;
    }

    @Transactional(readOnly = true)
    public List<WorkoutPlan> byStudent(UUID studentId) {
        return plans.findByStudent(studentId);
    }

    @Transactional(readOnly = true)
    public List<WorkoutPlan> myPlans(UUID userId) {
        Student s = students.findByUserId(userId)
                .orElseThrow(() -> new NotFoundException("Nenhum aluno vinculado a esta conta."));
        return plans.findByStudent(s.getId());
    }

    @Transactional(readOnly = true)
    public WorkoutPlan get(UUID id) {
        return plans.findByIdAndDeletedAtIsNull(id)
                .orElseThrow(() -> new NotFoundException("Ficha não encontrada."));
    }

    @Transactional
    public WorkoutPlan create(UpsertRequest req, UUID professorId) {
        Student student = students.findByIdAndDeletedAtIsNull(req.studentId())
                .orElseThrow(() -> new NotFoundException("Aluno não encontrado."));
        WorkoutPlan p = new WorkoutPlan();
        p.setStudent(student);
        p.setProfessorId(professorId);
        applyHeader(p, req);
        rebuildItems(p, req.exercises());
        return plans.save(p);
    }

    @Transactional
    public WorkoutPlan update(UUID id, UpsertRequest req) {
        WorkoutPlan p = get(id);
        applyHeader(p, req);
        p.getExercises().clear();     // orphanRemoval remove os antigos
        rebuildItems(p, req.exercises());
        return plans.save(p);
    }

    @Transactional
    public void delete(UUID id) {
        WorkoutPlan p = get(id);
        p.setDeletedAt(OffsetDateTime.now());
        p.setActive(false);
        plans.save(p);
    }

    private void applyHeader(WorkoutPlan p, UpsertRequest req) {
        if (req.sheetLabel() != null) p.setSheetLabel(req.sheetLabel());
        p.setTitle(req.title());
        if (req.active() != null) p.setActive(req.active());
        p.setValidUntil(req.validUntil());
    }

    private void rebuildItems(WorkoutPlan p, List<ItemRequest> items) {
        if (items == null) return;
        int ordem = 0;
        for (ItemRequest it : items) {
            WorkoutPlanExercise e = new WorkoutPlanExercise();
            e.setExerciseId(it.exerciseId());
            e.setExerciseName(resolveName(it));
            e.setOrdem(ordem++);
            e.setSets(it.sets());
            e.setReps(it.reps());
            e.setRestSeconds(it.restSeconds());
            e.setNotes(it.notes());
            p.addExercise(e);
        }
    }

    /** Snapshot do nome: usa o informado, senão busca do catálogo pelo exerciseId. */
    private String resolveName(ItemRequest it) {
        if (it.exerciseName() != null && !it.exerciseName().isBlank()) {
            return it.exerciseName();
        }
        if (it.exerciseId() != null) {
            return exercises.findById(it.exerciseId()).map(Exercise::getName).orElse(null);
        }
        return null;
    }
}
