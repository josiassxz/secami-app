package br.gov.goias.secami.training.coaching;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface ConviteRepository extends JpaRepository<Convite, UUID> {

    Optional<Convite> findByCodigo(String codigo);
}
