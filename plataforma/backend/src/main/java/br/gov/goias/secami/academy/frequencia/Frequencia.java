package br.gov.goias.secami.academy.frequencia;

import br.gov.goias.secami.academy.student.Student;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.OffsetDateTime;
import java.util.UUID;

/** Log bruto de acesso da catraca (entrada/saída). SPEC §8.3 / §9.6 (uso futuro). */
@Entity
@Table(name = "frequencia")
@Getter
@Setter
@NoArgsConstructor
public class Frequencia {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private Student student;

    @Column(name = "data_hora", nullable = false)
    private OffsetDateTime dataHora;

    @Column(nullable = false)
    private String tipo;                 // entrada | saida

    @Column(nullable = false)
    private String origem = "catraca";   // catraca | manual

    @Column(name = "legacy_id", unique = true)
    private String legacyId;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private OffsetDateTime createdAt;
}
