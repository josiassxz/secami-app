package br.gov.goias.secami.training.coaching;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface VinculoRepository extends JpaRepository<Vinculo, UUID> {

    List<Vinculo> findByProfessorIdAndStatusAndDeletedAtIsNull(UUID professorId, String status);

    List<Vinculo> findByAlunoIdAndStatusAndDeletedAtIsNull(UUID alunoId, String status);

    boolean existsByProfessorIdAndAlunoIdAndDeletedAtIsNull(UUID professorId, UUID alunoId);
}
