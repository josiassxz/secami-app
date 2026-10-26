package br.gov.goias.secami.academy.lutas;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public interface AcessoLutasRepository extends JpaRepository<AcessoLutas, UUID> {

    boolean existsByStudentIdAndData(UUID studentId, LocalDate data);

    /** Liberações vencidas que ainda têm vínculo no Accelero pra retirar. */
    @Query("""
            select a from AcessoLutas a join fetch a.student
            where a.acceleroVinculoId is not null and a.expiraEm < :agora
            """)
    List<AcessoLutas> findExpiradas(@Param("agora") OffsetDateTime agora);
}
