package br.gov.goias.secami.academy.atestado;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AtestadoEnvioRepository extends JpaRepository<AtestadoEnvio, UUID> {

    /** Último envio do aluno (o que importa pro status dele). */
    Optional<AtestadoEnvio> findFirstByStudentIdOrderByEnviadoEmDesc(UUID studentId);

    boolean existsByStudentIdAndStatus(UUID studentId, String status);

    @EntityGraph(attributePaths = {"student", "student.department"})
    List<AtestadoEnvio> findByStatusOrderByEnviadoEmAsc(String status);

    long countByStatus(String status);
}
