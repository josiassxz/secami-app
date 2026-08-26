package br.gov.goias.secami.training.plan;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class WorkoutPlanDtos {

    private WorkoutPlanDtos() {}

    public record ExerciseItem(
            UUID exerciseId, String exerciseName, int ordem,
            Integer sets, String reps, Integer restSeconds, String notes) {
        public static ExerciseItem from(WorkoutPlanExercise e) {
            return new ExerciseItem(e.getExerciseId(), e.getExerciseName(), e.getOrdem(),
                    e.getSets(), e.getReps(), e.getRestSeconds(), e.getNotes());
        }
    }

    public record Response(
            UUID id, UUID studentId, String studentName, UUID professorId,
            String sheetLabel, String title, boolean active, LocalDate validUntil,
            List<ExerciseItem> exercises) {
        public static Response from(WorkoutPlan p) {
            return new Response(p.getId(), p.getStudent().getId(), p.getStudent().getFullName(),
                    p.getProfessorId(), p.getSheetLabel(), p.getTitle(), p.isActive(), p.getValidUntil(),
                    p.getExercises().stream().map(ExerciseItem::from).toList());
        }
    }

    public record ItemRequest(
            UUID exerciseId,
            String exerciseName,
            Integer sets,
            String reps,
            Integer restSeconds,
            String notes
    ) {}

    public record UpsertRequest(
            @NotNull(message = "Informe o aluno.") UUID studentId,
            String sheetLabel,
            @NotBlank(message = "Informe o título da ficha.") String title,
            Boolean active,
            LocalDate validUntil,
            List<ItemRequest> exercises
    ) {}
}
