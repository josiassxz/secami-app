package br.gov.goias.secami.training.exercise;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface ExerciseRepository extends JpaRepository<Exercise, UUID> {

    Optional<Exercise> findByLegacyId(String legacyId);

    Optional<Exercise> findFirstByNameIgnoreCase(String name);

    /** Busca com filtros opcionais. Sentinela "" (nunca null) evita erro de tipo no Postgres. */
    @Query("""
            select e from Exercise e
            where e.arquivado = false
              and (:grupo = '' or e.muscleGroup = :grupo)
              and (:q = '' or lower(e.name) like lower(concat('%', :q, '%')))
            order by e.name asc
            """)
    List<Exercise> search(@Param("q") String q, @Param("grupo") String grupo);
}
