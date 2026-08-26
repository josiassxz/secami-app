package br.gov.goias.secami.training.log;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface WorkoutLogRepository extends JpaRepository<WorkoutLog, UUID> {

    @EntityGraph(attributePaths = "exercises")
    Optional<WorkoutLog> findByStudentIdAndDate(UUID studentId, LocalDate date);

    @EntityGraph(attributePaths = "exercises")
    @Query("""
            select l from WorkoutLog l
            where l.student.id = :studentId
            order by l.date desc
            """)
    List<WorkoutLog> findByStudent(@Param("studentId") UUID studentId);
}
