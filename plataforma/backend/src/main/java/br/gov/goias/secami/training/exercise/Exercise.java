package br.gov.goias.secami.training.exercise;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UpdateTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Exercício do catálogo (oficial ou custom do usuário). SPEC §8.4. */
@Entity
@Table(name = "exercise")
@Getter
@Setter
@NoArgsConstructor
public class Exercise {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @Column(nullable = false)
    private String name;

    /** Slug estável usado pelo app Flutter para resolver "seed:&lt;slug&gt;" (SPEC E9). */
    @Column(unique = true)
    private String slug;

    @Column(name = "muscle_group")
    private String muscleGroup;

    private String description;
    private String equipment;

    @Column(name = "padrao_movimento")
    private String padraoMovimento;

    @Column(name = "video_url")
    private String videoUrl;

    @Column(name = "photo_id")
    private UUID photoId;

    @Column(nullable = false)
    private String escopo = "global";          // global | custom

    @Column(name = "owner_user_id")
    private UUID ownerUserId;

    @Column(nullable = false)
    private boolean arquivado = false;

    @Column(name = "legacy_id", unique = true)
    private String legacyId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;

    @UpdateTimestamp
    @Column(name = "updated_at")
    private OffsetDateTime updatedAt;
}
