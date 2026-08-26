package br.gov.goias.secami.academy.slot;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface SlotConfigRepository extends JpaRepository<SlotConfig, UUID> {

    Optional<SlotConfig> findBySlotStart(String slotStart);

    Optional<SlotConfig> findByLegacyId(String legacyId);

    List<SlotConfig> findAllByOrderBySlotStartAsc();
}
