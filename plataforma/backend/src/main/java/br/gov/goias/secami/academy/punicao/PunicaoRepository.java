package br.gov.goias.secami.academy.punicao;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.List;
import java.util.UUID;

public interface PunicaoRepository extends JpaRepository<Punicao, UUID> {

    List<Punicao> findByStudentIdAndStatusInOrderByAplicadaEmAsc(UUID studentId, Collection<String> status);

    List<Punicao> findByStudentIdOrderByAplicadaEmDesc(UUID studentId);

    /** Cumpridas que não fecharam um ciclo e já passaram do prazo. */
    @Query("select p from Punicao p where p.status = 'CUMPRIDA' and p.cumpridaEm < :limite")
    List<Punicao> findCumpridasAntesDe(@Param("limite") OffsetDateTime limite);

    long countByStudentIdAndStatus(UUID studentId, String status);
}
