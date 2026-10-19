package br.gov.goias.secami.academy.configuracao;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.UpdateTimestamp;

import java.time.OffsetDateTime;

/** Configuração ajustável pelo admin (chave/valor). */
@Entity
@Table(name = "configuracao")
@Getter
@Setter
@NoArgsConstructor
public class Configuracao {

    @Id
    private String chave;

    @Column(nullable = false)
    private String valor;

    @UpdateTimestamp
    @Column(name = "atualizado_em")
    private OffsetDateTime atualizadoEm;
}
