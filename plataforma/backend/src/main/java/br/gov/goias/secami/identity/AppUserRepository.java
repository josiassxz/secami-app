package br.gov.goias.secami.identity;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface AppUserRepository extends JpaRepository<AppUser, UUID> {

    Optional<AppUser> findBySamAccountNameIgnoreCase(String samAccountName);

    Optional<AppUser> findByLdapGuid(UUID ldapGuid);

    Optional<AppUser> findByEmailIgnoreCase(String email);

    List<AppUser> findByNomeContainingIgnoreCaseOrEmailContainingIgnoreCase(String nome, String email);
}
