package br.gov.goias.secami.auth;

import java.util.Optional;
import java.util.UUID;

/** Abstrai a validação de credencial (e-mail + senha) contra {@code app_user}. */
public interface AuthProvider {

    /** @return id do usuário autenticado, ou vazio se e-mail/senha não confere. */
    Optional<UUID> authenticate(String email, String rawPassword);
}
