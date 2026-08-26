package br.gov.goias.secami.academy.checkin;

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

/** Presença (check-in/out) manual ou via catraca. SPEC §8.3 / §9.5. */
@Entity
@Table(name = "check_in")
@Getter
@Setter
@NoArgsConstructor
public class CheckIn {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private Student student;

    @Column(name = "appointment_id")
    private UUID appointmentId;

    @Column(nullable = false)
    private LocalDate date;

    @Column(name = "check_in_time", nullable = false)
    private String checkInTime;          // "HH:MM"

    @Column(name = "check_out_time")
    private String checkOutTime;

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
}
