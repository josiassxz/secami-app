package br.gov.goias.secami.training.log;

import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public final class WorkoutLogDtos {

    private WorkoutLogDtos() {}

    public record ExerciseEntry(String exerciseName, String load) {}

    public record Response(
            UUID id, LocalDate date, UUID workoutPlanId, String sheetLabel,
            boolean completed, List<ExerciseEntry> exercises) {
        public static Response from(WorkoutLog l) {
            return new Response(l.getId(), l.getDate(), l.getWorkoutPlanId(), l.getSheetLabel(),
                    l.isCompleted(),
                    l.getExercises().stream()
                            .map(e -> new ExerciseEntry(e.getExerciseName(), e.getLoad()))
                            .toList());
        }
    }

    public record UpsertRequest(
            @NotNull(message = "Informe a data.") LocalDate date,
            UUID workoutPlanId,
            String sheetLabel,
            List<ExerciseEntry> exercises
    ) {}
}
