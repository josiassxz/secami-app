package br.gov.goias.secami.academy.appointment;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDate;
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
}
