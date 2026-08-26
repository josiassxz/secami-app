package br.gov.goias.secami.auth;

import java.util.Optional;

/**
 * Abstrai a validação de credencial. Exatamente um bean fica ativo conforme
 * {@code secami.ldap.enabled}: {@link LdapAuthProvider} (prod) ou
 * {@link DevAuthProvider} (dev, sem rede corporativa).
 */
public interface AuthProvider {

    /** @return dados do usuário autenticado, ou vazio se credencial inválida. */
    Optional<AuthenticatedUser> authenticate(String username, String rawPassword);
}
