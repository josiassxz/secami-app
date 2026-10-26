package br.gov.goias.secami.academy.lutas;

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
import org.hibernate.annotations.UuidGenerator;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

/** Liberação do dia na catraca pra um aluno de Lutas (ver LutasAcessoService). */
@Entity
@Table(name = "acesso_lutas")
@Getter
@Setter
@NoArgsConstructor
public class AcessoLutas {

    @Id
    @UuidGenerator(style = UuidGenerator.Style.TIME)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "student_id")
    private Student student;

    @Column(nullable = false)
    private LocalDate data;

    @Column(name = "accelero_vinculo_id")
    private String acceleroVinculoId;

    @Column(name = "expira_em", nullable = false)
    private OffsetDateTime expiraEm;
}
