package br.gov.goias.secami.auth;

import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Optional;
import java.util.UUID;

/**
 * Provedor de autenticação por senha local: valida e-mail + senha contra
 * {@code app_user.password_hash} (Argon2). Não filtra por "ativo" aqui —
 * quem decide se um usuário inativo/pendente pode logar é o
 * {@link AuthService}, que dá uma mensagem específica (pendente de
 * aprovação, recusado, inativo) em vez de "credenciais inválidas".
 */
@Component
@Order(1)
public class LocalAuthProvider implements AuthProvider {

    private final AppUserRepository users;
    private final PasswordEncoder encoder;

    public LocalAuthProvider(AppUserRepository users, PasswordEncoder encoder) {
        this.users = users;
        this.encoder = encoder;
    }

    @Override
    public Optional<UUID> authenticate(String email, String rawPassword) {
        return users.findByEmailIgnoreCase(email)
                .filter(u -> u.getPasswordHash() != null
                        && encoder.matches(rawPassword, u.getPasswordHash()))
                .map(AppUser::getId);
    }
}
