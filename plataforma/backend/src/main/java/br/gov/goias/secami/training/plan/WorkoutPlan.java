package br.gov.goias.secami.training.plan;

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

/** Ficha de treino (A–D) prescrita a um aluno por um professor. SPEC §8.4. */
@Entity
@Table(name = "workout_plan")
@Getter
@Setter
@NoArgsConstructor
public class WorkoutPlan {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private Student student;

    @Column(name = "professor_id")
    private UUID professorId;

    @Column(name = "sheet_label", nullable = false)
    private String sheetLabel = "A";        // A | B | C | D

    @Column(nullable = false)
    private String title;

    @Column(nullable = false)
    private boolean active = true;

    @Column(name = "valid_until")
    private LocalDate validUntil;

    @OneToMany(mappedBy = "workoutPlan", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("ordem asc")
    private List<WorkoutPlanExercise> exercises = new ArrayList<>();

    @Column(name = "legacy_id", unique = true)
    private String legacyId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    @Column(name = "deleted_at")
    private OffsetDateTime deletedAt;

    public void addExercise(WorkoutPlanExercise e) {
        e.setWorkoutPlan(this);
        exercises.add(e);
    }
}
