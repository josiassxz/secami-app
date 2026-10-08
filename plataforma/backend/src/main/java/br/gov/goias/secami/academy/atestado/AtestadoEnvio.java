package br.gov.goias.secami.academy.atestado;

import br.gov.goias.secami.academy.student.Student;
import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;
import org.hibernate.annotations.UuidGenerator;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Novo atestado enviado pelo aluno no app, aguardando validação do admin. */
@Entity
@Table(name = "atestado_envio")
@Getter
@Setter
@NoArgsConstructor
public class AtestadoEnvio {

    public static final String PENDENTE = "PENDENTE";
    public static final String APROVADO = "APROVADO";
    public static final String RECUSADO = "RECUSADO";

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private Student student;

    @Column(name = "arquivo_id", nullable = false)
    private UUID arquivoId;

    @Column(name = "emissao_data", nullable = false)
    private LocalDate emissaoData;

    @Column(name = "medico_nome", nullable = false)
    private String medicoNome;

    @Column(name = "medico_crm", nullable = false)
    private String medicoCrm;

    @Column(name = "medico_crm_uf", nullable = false)
    private String medicoCrmUf;

    @Column(nullable = false)
    private String status = PENDENTE;

    @Column(name = "motivo_recusa")
    private String motivoRecusa;

    @CreationTimestamp
    @Column(name = "enviado_em", updatable = false)
    private OffsetDateTime enviadoEm;

    @Column(name = "analisado_em")
    private OffsetDateTime analisadoEm;

    @Column(name = "analisado_por")
    private UUID analisadoPor;
}
