package br.gov.goias.secami.academy.student;

import br.gov.goias.secami.academy.department.Department;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Perfil do aluno (Civil ou Militar). SPEC §8.2. */
@Entity
@Table(name = "student")
@Getter
@Setter
@NoArgsConstructor
public class Student {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    /** Vínculo com a identidade/login (app_user). */
    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(unique = true)
    private String cpf;                  // só dígitos, normalizado

    private String matricula;

    @Column(name = "student_type", nullable = false)
    private String studentType = "Civil";  // Civil | Militar

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "department_id")
    private Department department;

    private String phone;
    private String email;

    @Column(name = "birth_date")
    private LocalDate birthDate;

    @Column(name = "weight_kg")
    private BigDecimal weightKg;

    @Column(name = "height_cm")
    private BigDecimal heightCm;

    private String goal;

    @Column(name = "photo_id")
    private UUID photoId;

    @Column(name = "atestado_numero")
    private String atestadoNumero;

    @Column(name = "atestado_data")
    private LocalDate atestadoData;

    @Column(nullable = false)
    private boolean active = true;

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

    /** Atestado válido = existe e tem no máximo 1 ano (regra Civil). SPEC §9.4. */
    public boolean atestadoValido(LocalDate hoje) {
        return atestadoData != null && !atestadoData.isBefore(hoje.minusYears(1));
    }
}
