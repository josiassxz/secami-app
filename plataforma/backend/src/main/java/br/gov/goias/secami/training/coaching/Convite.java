package br.gov.goias.secami.training.coaching;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Convite de coaching (código a compartilhar). SPEC §8.6. */
@Entity
@Table(name = "convite")
@Getter
@Setter
@NoArgsConstructor
public class Convite {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @Column(nullable = false, unique = true)
    private String codigo;

    @Column(nullable = false)
    private String tipo = "professor_aluno";   // professor_aluno | org_professor

    @Column(name = "criado_por", nullable = false)
    private UUID criadoPor;

    @Column(name = "org_id")
    private UUID orgId;

    @Column(name = "usos_max", nullable = false)
    private int usosMax = 1;

    @Column(nullable = false)
    private int usos = 0;

    @Column(name = "expira_em", nullable = false)
    private OffsetDateTime expiraEm;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    public boolean valido(OffsetDateTime agora) {
        return usos < usosMax && expiraEm.isAfter(agora);
    }
}
