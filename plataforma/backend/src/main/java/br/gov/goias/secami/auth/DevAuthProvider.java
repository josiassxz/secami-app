package br.gov.goias.secami.auth;

import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Optional;

/**
 * Provider de desenvolvimento: valida a senha contra {@code app_user.password_hash}
 * (Argon2). Ativo quando LDAP está desabilitado (sem rede AD). SPEC §12.
 */
@Component
@ConditionalOnProperty(name = "secami.ldap.enabled", havingValue = "false", matchIfMissing = true)
public class DevAuthProvider implements AuthProvider {

    private final AppUserRepository users;
    private final PasswordEncoder encoder;

    public DevAuthProvider(AppUserRepository users, PasswordEncoder encoder) {
        this.users = users;
        this.encoder = encoder;
    }

    @Override
    public Optional<AuthenticatedUser> authenticate(String username, String rawPassword) {
        return users.findBySamAccountNameIgnoreCase(username)
                .filter(AppUser::isAtivo)
                .filter(u -> u.getPasswordHash() != null
                        && encoder.matches(rawPassword, u.getPasswordHash()))
                .map(u -> new AuthenticatedUser(
                        u.getLdapGuid(),
                        u.getSamAccountName(),
                        u.getEmail(),
                        u.getNome(),
                        "local"));
    }
}
