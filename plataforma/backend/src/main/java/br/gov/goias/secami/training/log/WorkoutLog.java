package br.gov.goias.secami.training.log;

import br.gov.goias.secami.academy.student.Student;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Execução diária de uma ficha de treino pelo aluno. SPEC §8.4 / §9.3. */
@Entity
@Table(name = "workout_log")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutLog {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private Student student;

    @Column(name = "workout_plan_id")
    private UUID workoutPlanId;

    @Column(name = "sheet_label")
    private String sheetLabel;

    @Column(nullable = false)
    private LocalDate date;

    @Column(nullable = false)
    private boolean completed = false;

    @OneToMany(mappedBy = "workoutLog", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<WorkoutLogExercise> exercises = new ArrayList<>();

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    public void addExercise(WorkoutLogExercise e) {
        e.setWorkoutLog(this);
        exercises.add(e);
    }
}
