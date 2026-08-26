package br.gov.goias.secami.academy.slot;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Configuração de uma janela de 1h de agendamento. SPEC §8.3 / §9.4. */
@Entity
@Table(name = "slot_config")
@Getter
@Setter
@NoArgsConstructor
public class SlotConfig {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @Column(name = "slot_start", nullable = false, unique = true)
    private String slotStart;            // "HH:MM"

    @Column(name = "slot_end", nullable = false)
    private String slotEnd;

    @Column(name = "max_capacity", nullable = false)
    private int maxCapacity = 40;

    @Column(name = "civil_restricted", nullable = false)
    private boolean civilRestricted = false;

    @Column(nullable = false)
    private boolean blocked = false;

    @Column(name = "block_reason")
    private String blockReason;

    @Column(name = "legacy_id", unique = true)
    private String legacyId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
