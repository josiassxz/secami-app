package br.gov.goias.secami.academy.slot;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface BlockedDateRepository extends JpaRepository<BlockedDate, UUID> {

    Optional<BlockedDate> findByLegacyId(String legacyId);

    List<BlockedDate> findByDate(LocalDate date);

    List<BlockedDate> findByDateGreaterThanEqualOrderByDateAsc(LocalDate date);
}
