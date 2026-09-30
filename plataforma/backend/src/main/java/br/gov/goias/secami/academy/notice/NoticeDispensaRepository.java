package br.gov.goias.secami.academy.notice;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Set;
import java.util.UUID;

public interface NoticeDispensaRepository extends JpaRepository<NoticeDispensa, NoticeDispensa.Chave> {

    /** Avisos que o usuário já dispensou ("não mostrar novamente"). */
    @Query("select d.id.noticeId from NoticeDispensa d where d.id.userId = :userId")
    Set<UUID> avisosDispensadosPor(@Param("userId") UUID userId);
}
