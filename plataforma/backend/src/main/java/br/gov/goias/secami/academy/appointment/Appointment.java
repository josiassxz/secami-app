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

    /** Vínculo (UID) da liberação dinâmica de acesso no Accelero pra este
     *  agendamento (Civil) — usado pra revogar exatamente essa liberação se
     *  o agendamento for cancelado, ou removê-la quando a janela expirar
     *  (ver AcceleroExpiracaoService). Null se não liberado (Militar,
     *  Accelero desligado, a liberação falhou, ou já foi revogada/removida). */
    @Column(name = "accelero_acesso_vinculo_id")
    private String acceleroAcessoVinculoId;

    /** Fim da janela de acesso liberada no Accelero (início marcado + 5h) —
     *  usado pelo job que remove o vínculo acima depois que ela passa. */
    @Column(name = "accelero_acesso_expira_em")
    private OffsetDateTime acceleroAcessoExpiraEm;

    /** Confirmação REAL de entrada/saída pela catraca (Accelero), preenchida
     *  pelo job AcceleroPresencaService — distinto do check-in autodeclarado
     *  (CheckIn.checkInTime/checkOutTime), que é manual/pode não acontecer
     *  mesmo com presença física real. Null até o job confirmar. */
    @Column(name = "entrada_confirmada_em")
    private OffsetDateTime entradaConfirmadaEm;

    @Column(name = "saida_confirmada_em")
    private OffsetDateTime saidaConfirmadaEm;

    public boolean ativo() {
        return deletedAt == null && !CANCELADO.equals(status);
    }
}
