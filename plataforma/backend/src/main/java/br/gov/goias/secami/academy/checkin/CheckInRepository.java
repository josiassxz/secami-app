package br.gov.goias.secami.academy.checkin;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface CheckInRepository extends JpaRepository<CheckIn, UUID> {

    Optional<CheckIn> findByLegacyId(String legacyId);

    @Query("select c from CheckIn c join fetch c.student where c.date = :date order by c.checkInTime asc")
    List<CheckIn> findByDate(@Param("date") LocalDate date);

    @Query("select c from CheckIn c join fetch c.student where c.id = :id")
    java.util.Optional<CheckIn> findByIdWithStudent(@Param("id") UUID id);

    boolean existsByStudentIdAndDate(UUID studentId, LocalDate date);

    List<CheckIn> findByStudentIdOrderByDateDesc(UUID studentId);

    long countByStudentIdAndDate(UUID studentId, LocalDate date);

    long countByDate(LocalDate date);

    @Query("""
            select c from CheckIn c
            where c.date = :date and c.checkOutTime is null
            """)
    List<CheckIn> findSemCheckout(@Param("date") LocalDate date);
}
