package br.gov.goias.secami.academy.appointment;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AppointmentRepository extends JpaRepository<Appointment, UUID> {

    Optional<Appointment> findByLegacyId(String legacyId);

    /** Agendamentos ativos (não cancelados, não excluídos) do aluno de hoje em diante. */
    @Query("""
            select count(a) from Appointment a
            where a.student.id = :studentId
              and a.deletedAt is null and a.status <> 'cancelado'
              and a.date >= :hoje
            """)
    long countAtivosFuturos(@Param("studentId") UUID studentId, @Param("hoje") LocalDate hoje);

    @Query("""
            select count(a) from Appointment a
            where a.student.id = :studentId and a.date = :date
              and a.deletedAt is null and a.status <> 'cancelado'
            """)
    long countAtivosNoDia(@Param("studentId") UUID studentId, @Param("date") LocalDate date);

    @Query("""
            select count(a) from Appointment a
            where a.student.id = :studentId and a.date = :date and a.slotStart = :slotStart
              and a.deletedAt is null and a.status <> 'cancelado'
            """)
    long countAtivosNoSlot(@Param("studentId") UUID studentId,
                           @Param("date") LocalDate date,
                           @Param("slotStart") String slotStart);

    /** Ocupação de civis num slot (aplica o cap de capacidade). SPEC §9.4. */
    @Query("""
            select count(a) from Appointment a
            where a.date = :date and a.slotStart = :slotStart
              and a.deletedAt is null and a.status <> 'cancelado'
              and (a.student.studentType = 'Civil' or a.student.studentType is null)
            """)
    long countCivisNoSlot(@Param("date") LocalDate date, @Param("slotStart") String slotStart);

    @Query("""
            select a from Appointment a join fetch a.student
            where a.student.id = :studentId and a.deletedAt is null
            order by a.date desc, a.slotStart desc
            """)
    List<Appointment> findByStudent(@Param("studentId") UUID studentId);

    @Query("""
            select a from Appointment a join fetch a.student
            where a.date between :from and :to and a.deletedAt is null
            order by a.date asc, a.slotStart asc
            """)
    List<Appointment> findByDateRange(@Param("from") LocalDate from, @Param("to") LocalDate to);

    @Query("""
            select a from Appointment a join fetch a.student
            where a.date = :date and a.deletedAt is null
            order by a.slotStart asc
            """)
    List<Appointment> findByDateAndDeletedAtIsNull(@Param("date") LocalDate date);

    /** Candidatos à marcação automática de falta (job E11). */
    @Query("""
            select a from Appointment a
            where a.status = 'agendado' and a.deletedAt is null and a.date <= :hoje
            """)
    List<Appointment> findAgendadosAte(@Param("hoje") LocalDate hoje);

    long countByDateAndDeletedAtIsNull(LocalDate date);

    /** Agendamento ativo do aluno numa data (para vincular ao check-in). */
    @Query("""
            select a from Appointment a
            where a.student.id = :studentId and a.date = :date
              and a.deletedAt is null and a.status in ('agendado','confirmado')
            order by a.slotStart asc
            """)
    List<Appointment> findAtivosDoDia(@Param("studentId") UUID studentId, @Param("date") LocalDate date);

    /** Acessos dinâmicos (civil) com a janela já expirada, ainda não removidos
     *  do Accelero — candidatos do job de limpeza (AcceleroExpiracaoService). */
    @Query("""
            select a from Appointment a join fetch a.student
            where a.acceleroAcessoVinculoId is not null and a.acceleroAcessoExpiraEm < :agora
            """)
    List<Appointment> findComAcessoAcceleroExpirado(@Param("agora") OffsetDateTime agora);

    /** Agendamentos ainda sem confirmação real de entrada E/OU saída (pessoa
     *  vinculada ao Accelero) nas datas informadas — candidatos do job de
     *  confirmação de presença (AcceleroPresencaService). */
    @Query("""
            select a from Appointment a join fetch a.student s
            where a.date in :datas and a.deletedAt is null and a.status <> 'cancelado'
              and s.acceleroPessoaId is not null
              and (a.entradaConfirmadaEm is null or a.saidaConfirmadaEm is null)
            """)
    List<Appointment> findCandidatosConfirmacaoPresenca(@Param("datas") List<LocalDate> datas);

    /** Histórico de agendamentos do aluno num período (para modal de detalhes). */
    @Query("""
            select a from Appointment a join fetch a.student
            where a.student.id = :studentId
              and a.date between :from and :to
              and a.deletedAt is null
            order by a.date desc, a.slotStart desc
            """)
    List<Appointment> findByStudentIdAndDateBetween(
            @Param("studentId") UUID studentId,
            @Param("from") LocalDate from,
            @Param("to") LocalDate to);

    /** Listagem paginada com filtros acumulativos para relatórios (Fase 3A).
     *  {@code cast(:q as String)}: sem o cast, um :q nulo (busca vazia — o
     *  caso padrão da tela) chega ao Postgres tipado como bytea e o
     *  lower() falha com "function lower(bytea) does not exist". */
    @Query("""
            select a from Appointment a join fetch a.student s
            where a.date between :from and :to
              and a.deletedAt is null
              and (:status is null or a.status = :status)
              and (cast(:q as String) is null
                   or lower(s.fullName) like lower(concat('%', cast(:q as String), '%'))
                   or s.cpf like concat('%', cast(:q as String), '%'))
            order by a.date asc, a.slotStart asc
            """)
    Page<Appointment> findByDateRangeFiltered(
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("status") String status,
            @Param("q") String q,
            Pageable pageable);

    /** Contagens agregadas por status + métricas para cards de resumo (Fase 3A).
     *  Casts explícitos pelo mesmo motivo da listagem: parâmetro nulo numa
     *  query nativa chega sem tipo (bytea) ao Postgres. */
    @Query(value = """
            select a.status, count(a),
                   avg(case when a.entrada_confirmada_em is not null and a.saida_confirmada_em is not null
                            then extract(epoch from (a.saida_confirmada_em - a.entrada_confirmada_em)) / 60.0
                            else null end),
                   sum(case when a.entrada_confirmada_em is not null then 1 else 0 end)
            from appointment a
            where a.date between :from and :to
              and a.deleted_at is null
              and (cast(:status as text) is null or a.status = cast(:status as text))
              and (cast(:q as text) is null or exists (select 1 from student s where s.id = a.student_id
                     and (lower(s.full_name) like lower(concat('%', cast(:q as text), '%'))
                          or s.cpf like concat('%', cast(:q as text), '%'))))
            group by a.status
            """, nativeQuery = true)
    List<Object[]> summarizeByRange(
            @Param("from") LocalDate from,
            @Param("to") LocalDate to,
            @Param("status") String status,
            @Param("q") String q);
}
