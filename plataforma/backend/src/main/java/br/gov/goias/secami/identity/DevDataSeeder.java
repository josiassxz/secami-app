package br.gov.goias.secami.identity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.Set;

/**
 * Semeia usuários de desenvolvimento (senha padrão). Desligar via
 * secami.dev-auth.enabled=false em produção. Login é por e-mail (ver
 * LocalAuthProvider) — os e-mails abaixo são as credenciais de dev.
 * Senha de todos: {@code secami123}.
 */
@Component
@ConditionalOnProperty(name = "secami.dev-auth.enabled", havingValue = "true", matchIfMissing = true)
public class DevDataSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DevDataSeeder.class);
    private static final String DEV_PASSWORD = "secami123";

    private final AppUserRepository users;
    private final PasswordEncoder encoder;

    public DevDataSeeder(AppUserRepository users, PasswordEncoder encoder) {
        this.users = users;
        this.encoder = encoder;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (users.count() > 0) {
            return; // já semeado / dados reais presentes
        }
        String hash = encoder.encode(DEV_PASSWORD);
        seed("admin", "Administrador SECAMI", "admin@dev.secami", Set.of(Roles.ADMIN), hash);
        seed("gerente", "Gerente SECAMI", "gerente@dev.secami", Set.of(Roles.GERENTE), hash);
        seed("recepcao", "Recepção SECAMI", "recepcao@dev.secami", Set.of(Roles.RECEPCAO), hash);
        seed("professor", "Professor SECAMI", "professor@dev.secami", Set.of(Roles.PROFESSOR), hash);
        seed("aluno", "Aluno SECAMI", "aluno@dev.secami", Set.of(Roles.ALUNO), hash);
        log.warn("[DEV] Usuários semeados (senha '{}'): admin@dev.secami, gerente@dev.secami, "
                + "recepcao@dev.secami, professor@dev.secami, aluno@dev.secami", DEV_PASSWORD);
    }

    private void seed(String sam, String nome, String email, Set<String> roles, String hash) {
        AppUser u = new AppUser();
        u.setSamAccountName(sam);
        u.setNome(nome);
        u.setEmail(email);
        u.setTipoIdentidade("local");
        u.setAtivo(true);
        u.setPasswordHash(hash);
        u.getRoles().addAll(roles);
        users.save(u);
    }
}
