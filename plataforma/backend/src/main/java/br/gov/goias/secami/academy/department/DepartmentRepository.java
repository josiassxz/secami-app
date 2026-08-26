package br.gov.goias.secami.academy.department;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.UUID;

public interface DepartmentRepository extends JpaRepository<Department, UUID> {

    Optional<Department> findByLegacyId(String legacyId);

    Optional<Department> findFirstByNameIgnoreCase(String name);
}
