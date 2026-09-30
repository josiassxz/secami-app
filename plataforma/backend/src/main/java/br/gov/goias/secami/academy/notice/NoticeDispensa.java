package br.gov.goias.secami.academy.notice;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;
import jakarta.persistence.EmbeddedId;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.EqualsAndHashCode;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.CreationTimestamp;

import java.io.Serializable;
import java.time.OffsetDateTime;
import java.util.UUID;

/** "Não mostrar novamente": o usuário dispensou a janela deste aviso no app. */
@Entity
@Table(name = "notice_dispensa")
@Getter
@Setter
@NoArgsConstructor
public class NoticeDispensa {

    @EmbeddedId
    private Chave id;

    @CreationTimestamp
    @Column(name = "dispensado_em", updatable = false)
    private OffsetDateTime dispensadoEm;

    public NoticeDispensa(UUID noticeId, UUID userId) {
        this.id = new Chave(noticeId, userId);
    }

    @Embeddable
    @Getter
    @Setter
    @NoArgsConstructor
    @EqualsAndHashCode
    public static class Chave implements Serializable {
        @Column(name = "notice_id")
        private UUID noticeId;

        @Column(name = "user_id")
        private UUID userId;

        public Chave(UUID noticeId, UUID userId) {
            this.noticeId = noticeId;
            this.userId = userId;
        }
    }
}
