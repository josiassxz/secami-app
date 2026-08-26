package br.gov.goias.secami.academy.slot;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Bloqueio de data (dia inteiro ou um slot). SPEC §8.3. */
@Entity
@Table(name = "blocked_date")
@Getter
@Setter
@NoArgsConstructor
public class BlockedDate {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @Column(nullable = false)
    private LocalDate date;

    @Column(name = "slot_start")
    private String slotStart;            // null = dia inteiro

    private String reason;

    @Column(name = "legacy_id", unique = true)
    private String legacyId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;
}
