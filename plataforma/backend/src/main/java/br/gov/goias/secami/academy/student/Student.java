package br.gov.goias.secami.academy.student;

import br.gov.goias.secami.academy.department.Department;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
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

    /** Multi-select do formulário de cadastro (emagrecimento, hipertrofia...). */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(nullable = false, columnDefinition = "jsonb")
    private List<String> objetivos = new java.util.ArrayList<>();

    /** Respostas do questionário PAR-Q (10 perguntas sim/não), dado sensível de saúde. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "par_q", columnDefinition = "jsonb")
    private java.util.Map<String, Boolean> parQ;

    @Column(name = "termo_responsabilidade_aceito_em")
    private OffsetDateTime termoResponsabilidadeAceitoEm;

    @Column(name = "termo_ciencia_aceito_em")
    private OffsetDateTime termoCienciaAceitoEm;

    @Column(name = "medico_nome")
    private String medicoNome;

    @Column(name = "medico_crm")
    private String medicoCrm;

    @Column(name = "medico_crm_uf")
    private String medicoCrmUf;

    @Column(name = "atestado_emissao_data")
    private LocalDate atestadoEmissaoData;

    @Column(name = "atestado_arquivo_id")
    private UUID atestadoArquivoId;

    public static final String STATUS_PENDENTE = "pendente";
    public static final String STATUS_APROVADO = "aprovado";
    public static final String STATUS_REJEITADO = "rejeitado";

    @Column(name = "status_cadastro", nullable = false)
    private String statusCadastro = STATUS_APROVADO;

    @Column(name = "motivo_rejeicao")
    private String motivoRejeicao;

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
