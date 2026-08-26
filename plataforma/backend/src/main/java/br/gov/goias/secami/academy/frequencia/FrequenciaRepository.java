package br.gov.goias.secami.academy.frequencia;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FrequenciaRepository extends JpaRepository<Frequencia, UUID> {

    Optional<Frequencia> findByLegacyId(String legacyId);

    List<Frequencia> findByStudentIdOrderByDataHoraDesc(UUID studentId);

    List<Frequencia> findByDataHoraBetweenOrderByDataHoraDesc(OffsetDateTime from, OffsetDateTime to);
}
