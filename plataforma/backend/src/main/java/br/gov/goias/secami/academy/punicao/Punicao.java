package br.gov.goias.secami.academy.punicao;

import br.gov.goias.secami.academy.student.Student;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.annotations.UuidGenerator;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Punição aplicada a um aluno de Lutas. PENDENTE → CUMPRIDA → CONCLUIDA. */
@Entity
@Table(name = "punicao")
@Getter
@Setter
@NoArgsConstructor
public class Punicao {

    public static final String PENDENTE = "PENDENTE";
    public static final String CUMPRIDA = "CUMPRIDA";
    public static final String CONCLUIDA = "CONCLUIDA";

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private Student student;

    /** Cópia dos itens no momento da aplicação: [{itemId, nome}]. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(nullable = false)
    private List<Map<String, String>> itens = new ArrayList<>();

    private String observacao;

    @Column(nullable = false)
    private String status = PENDENTE;

    @Column(name = "aplicada_em", nullable = false)
    private OffsetDateTime aplicadaEm;

    @Column(name = "aplicada_por")
    private UUID aplicadaPor;

    @Column(name = "cumprida_em")
    private OffsetDateTime cumpridaEm;

    @Column(name = "cumprida_por")
    private UUID cumpridaPor;

    @Column(name = "concluida_em")
    private OffsetDateTime concluidaEm;
}
