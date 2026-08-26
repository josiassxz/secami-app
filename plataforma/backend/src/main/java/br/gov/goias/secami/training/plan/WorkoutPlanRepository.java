package br.gov.goias.secami.training.plan;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WorkoutPlanRepository extends JpaRepository<WorkoutPlan, UUID> {

    @EntityGraph(attributePaths = {"exercises", "student"})
    @Query("""
            select p from WorkoutPlan p
            where p.student.id = :studentId and p.deletedAt is null
            order by p.sheetLabel asc, p.createdAt desc
            """)
    List<WorkoutPlan> findByStudent(@Param("studentId") UUID studentId);

    @EntityGraph(attributePaths = {"exercises", "student"})
    Optional<WorkoutPlan> findByIdAndDeletedAtIsNull(UUID id);
}
