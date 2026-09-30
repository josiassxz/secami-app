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

    /**
     * Listagem/busca paginada. {@code termo} e {@code perfil} vazios ('') = sem
     * filtro — string vazia em vez de null de propósito: parâmetro nulo chega
     * sem tipo ao Postgres e quebra o lower()/comparação (ver
     * AppointmentRepository.findByDateRangeFiltered).
     *
     * @param perfil '' (todos), 'aluno' (Civil/Militar) ou 'instrutor'
     */
    @EntityGraph(attributePaths = "department")
    @Query("""
            select s from Student s
            where s.deletedAt is null
              and s.statusCadastro = :statusCadastro
              and ( :termo = ''
                    or lower(s.fullName) like lower(concat('%', :termo, '%'))
                    or s.cpf like concat('%', :termo, '%') )
              and ( :perfil = ''
                    or (:perfil = 'instrutor' and s.studentType = 'Instrutor')
                    or (:perfil = 'aluno' and s.studentType <> 'Instrutor') )
            order by s.fullName asc
            """)
    Page<Student> buscar(@Param("termo") String termo, @Param("statusCadastro") String statusCadastro,
                         @Param("perfil") String perfil, Pageable pageable);

    long countByDeletedAtIsNullAndStatusCadastroAndActiveTrue(String statusCadastro);

    long countByDeletedAtIsNullAndStudentType(String studentType);

    @EntityGraph(attributePaths = "department")
    java.util.List<Student> findByStatusCadastroAndDeletedAtIsNullOrderByCreatedAtAsc(String statusCadastro);

    /** Migrados do legado (têm legacyId) que ainda não têm login — candidatos do provisionamento em massa. */
    java.util.List<Student> findByDeletedAtIsNullAndUserIdIsNullAndLegacyIdIsNotNull();

    /** Já vinculados ao Accelero — candidatos da atualização de e-mail em massa. */
    java.util.List<Student> findByAcceleroPessoaIdIsNotNullAndDeletedAtIsNull();

    /** Alunos com CPF — candidatos da atualização de e-mail a partir do AD. */
    java.util.List<Student> findByCpfIsNotNullAndDeletedAtIsNull();

    /** Alunos ATIVOS com atestado vencido (mais de 1 ano) — para job de auto-inativação. */
    @Query("""
        select s from Student s
        where s.situacao = 'ATIVO'
          and s.deletedAt is null
          and s.atestadoData is not null
          and s.atestadoData < :limite
        """)
    java.util.List<Student> findComAtestadoVencido(@Param("limite") java.time.LocalDate limite);
}
