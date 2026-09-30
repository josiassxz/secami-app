package br.gov.goias.secami.academy.notice;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/** Aviso/informativo exibido por papel. SPEC §8.7. */
@Entity
@Table(name = "notice")
@Getter
@Setter
@NoArgsConstructor
public class Notice {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false)
    private String content;

    @Column(nullable = false)
    private String type = "info";        // info | warning | success

    @Column(nullable = false)
    private boolean active = true;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "target_roles", nullable = false, columnDefinition = "jsonb")
    private List<String> targetRoles = new ArrayList<>(List.of("aluno"));

    /** Primeiro dia em que o aviso aparece (inclusive). Nulo = desde já. */
    @Column(name = "exibir_de")
    private java.time.LocalDate exibirDe;

    /** Último dia em que o aviso aparece (inclusive). Nulo = sem data de fim. */
    @Column(name = "exibir_ate")
    private java.time.LocalDate exibirAte;

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

    /** Ativo e com {@code hoje} dentro do período de exibição (datas inclusive). */
    public boolean emExibicao(java.time.LocalDate hoje) {
        return active
                && (exibirDe == null || !hoje.isBefore(exibirDe))
                && (exibirAte == null || !hoje.isAfter(exibirAte));
    }

    /** Sem papel-alvo = todos; senão, basta o usuário ter um dos papéis. */
    public boolean visivelPara(java.util.Collection<String> papeis) {
        return targetRoles == null || targetRoles.isEmpty() || targetRoles.stream().anyMatch(papeis::contains);
    }
}
