package br.gov.goias.secami.academy.notice;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface NoticeRepository extends JpaRepository<Notice, UUID> {

    List<Notice> findByActiveTrueOrderByCreatedAtDesc();

    Optional<Notice> findByLegacyId(String legacyId);
}
