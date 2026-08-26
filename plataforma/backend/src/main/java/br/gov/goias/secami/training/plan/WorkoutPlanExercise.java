package br.gov.goias.secami.training.plan;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

/** Item de uma ficha (exercício prescrito com séries/reps/descanso). SPEC §8.4. */
@Entity
@Table(name = "workout_plan_exercise")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutPlanExercise {

    @Id
    @org.hibernate.annotations.UuidGenerator(style = org.hibernate.annotations.UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_plan_id")
    private WorkoutPlan workoutPlan;

    @Column(name = "exercise_id")
    private UUID exerciseId;

    @Column(name = "exercise_name")
    private String exerciseName;         // snapshot do nome (fallback)

    @Column(nullable = false)
    private int ordem = 0;

    private Integer sets;
    private String reps;

    @Column(name = "rest_seconds")
    private Integer restSeconds;

    private String notes;
}
