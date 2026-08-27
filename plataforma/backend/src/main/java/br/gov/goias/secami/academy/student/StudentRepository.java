package br.gov.goias.secami.academy.student;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface StudentRepository extends JpaRepository<Student, UUID> {

    @EntityGraph(attributePaths = "department")
    Optional<Student> findByIdAndDeletedAtIsNull(UUID id);

    Optional<Student> findByCpf(String cpf);

    Optional<Student> findByLegacyId(String legacyId);

    @EntityGraph(attributePaths = "department")
    Optional<Student> findByUserId(UUID userId);

    @EntityGraph(attributePaths = "department")
    Page<Student> findByDeletedAtIsNullOrderByFullNameAsc(Pageable pageable);

    @EntityGraph(attributePaths = "department")
    @Query("""
            select s from Student s
            where s.deletedAt is null
              and ( lower(s.fullName) like lower(concat('%', :q, '%'))
                    or s.cpf like concat('%', :q, '%') )
            order by s.fullName asc
            """)
    Page<Student> searchTerm(@Param("q") String q, Pageable pageable);

    long countByDeletedAtIsNullAndActiveTrue();

    long countByDeletedAtIsNullAndStudentType(String studentType);

    @EntityGraph(attributePaths = "department")
    java.util.List<Student> findByStatusCadastroAndDeletedAtIsNullOrderByCreatedAtAsc(String statusCadastro);
}
