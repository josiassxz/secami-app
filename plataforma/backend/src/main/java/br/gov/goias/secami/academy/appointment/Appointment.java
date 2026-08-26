package br.gov.goias.secami.academy.appointment;

import br.gov.goias.secami.academy.student.Student;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Agendamento de horário. SPEC §8.3 / §9.4. */
@Entity
@Table(name = "appointment")
@Getter
@Setter
@NoArgsConstructor
public class Appointment {

    public static final String AGENDADO = "agendado";
    public static final String CONFIRMADO = "confirmado";
    public static final String CANCELADO = "cancelado";
    public static final String FALTOU = "faltou";

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private Student student;

    @Column(nullable = false)
    private LocalDate date;

    @Column(name = "slot_start", nullable = false)
    private String slotStart;

    @Column(name = "slot_end", nullable = false)
    private String slotEnd;

    @Column(nullable = false)
    private String status = AGENDADO;

    @Column(nullable = false)
    private boolean forced = false;

    /** Evita reenviar o lembrete de 1h antes em execuções vizinhas do cron. */
    @Column(name = "lembrete_enviado", nullable = false)
    private boolean lembreteEnviado = false;

    private String notes;

    @Column(name = "created_by")
    private UUID createdBy;

    @Column(name = "legacy_id", unique = true)
    private String legacyId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    @Column(name = "deleted_at")
    private OffsetDateTime deletedAt;

    public boolean ativo() {
        return deletedAt == null && !CANCELADO.equals(status);
    }
}
