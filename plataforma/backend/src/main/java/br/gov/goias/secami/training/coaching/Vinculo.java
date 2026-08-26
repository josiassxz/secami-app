package br.gov.goias.secami.training.coaching;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Vínculo professor ↔ aluno. SPEC §8.6. */
@Entity
@Table(name = "vinculo")
@Getter
@Setter
@NoArgsConstructor
public class Vinculo {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @Column(name = "professor_id", nullable = false)
    private UUID professorId;

    @Column(name = "aluno_id", nullable = false)
    private UUID alunoId;

    @Column(nullable = false)
    private String status = "ativo";      // ativo | pendente | encerrado

    @Column(name = "aceito_em")
    private OffsetDateTime aceitoEm;

    @Column(name = "org_id")
    private UUID orgId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;

    @Column(name = "deleted_at")
    private OffsetDateTime deletedAt;
}
