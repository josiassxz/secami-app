package br.gov.goias.secami.academy.punicao;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PunicaoItemRepository extends JpaRepository<PunicaoItem, UUID> {

    List<PunicaoItem> findAllByOrderByNomeAsc();

    List<PunicaoItem> findByAtivoTrueOrderByNomeAsc();
}
