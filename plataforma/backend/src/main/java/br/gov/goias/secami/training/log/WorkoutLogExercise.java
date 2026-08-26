package br.gov.goias.secami.training.log;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.UuidGenerator;

import java.util.UUID;

/** Um exercício marcado (com carga) dentro de um {@link WorkoutLog}. */
@Entity
@Table(name = "workout_log_exercise")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutLogExercise {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_log_id")
    private WorkoutLog workoutLog;

    @Column(name = "exercise_name", nullable = false)
    private String exerciseName;

    private String load;

    @Column(nullable = false)
    private boolean completed = true;
}
