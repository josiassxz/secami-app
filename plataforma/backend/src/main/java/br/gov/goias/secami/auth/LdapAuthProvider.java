package br.gov.goias.secami.auth;

import br.gov.goias.secami.config.SecamiProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.ldap.core.ContextMapper;
import org.springframework.ldap.core.DirContextOperations;
import org.springframework.ldap.core.LdapTemplate;
import org.springframework.ldap.core.support.LdapContextSource;
import org.springframework.ldap.query.LdapQueryBuilder;
import org.springframework.ldap.support.LdapUtils;
import org.springframework.stereotype.Component;

import javax.naming.directory.DirContext;
import java.nio.ByteBuffer;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * Autenticação real contra o Active Directory Goiás (SPEC §12). Fluxo:
 * (1) bind com a conta de serviço; (2) busca o usuário sob baseDn pelo
 * loginAttribute aplicando o userFilter (só usuários ativos); (3) re-bind com o
 * DN do usuário + senha informada para validar a credencial. Ativo apenas quando
 * {@code secami.ldap.enabled=true}.
 */
@Component
@ConditionalOnProperty(name = "secami.ldap.enabled", havingValue = "true")
public class LdapAuthProvider implements AuthProvider {

    private static final Logger log = LoggerFactory.getLogger(LdapAuthProvider.class);

    private final SecamiProperties.Ldap cfg;
    private final LdapContextSource contextSource;

    public LdapAuthProvider(SecamiProperties props) {
        this.cfg = props.getLdap();
        this.contextSource = buildContextSource();
    }

    private LdapContextSource buildContextSource() {
        LdapContextSource cs = new LdapContextSource();
        cs.setUrl(cfg.url());
        cs.setBase(cfg.getBaseDn());
        cs.setUserDn(cfg.getBindDn());
        cs.setPassword(cfg.getBindPassword());
        Map<String, Object> env = new HashMap<>();
        env.put("java.naming.ldap.attributes.binary", "objectGUID");
        cs.setBaseEnvironmentProperties(env);
        cs.setPooled(true);
        cs.afterPropertiesSet();
        return cs;
    }

    @Override
    public Optional<AuthenticatedUser> authenticate(String username, String rawPassword) {
        if (rawPassword == null || rawPassword.isBlank()) {
            return Optional.empty();
        }
        LdapTemplate tpl = new LdapTemplate(contextSource);
        tpl.setIgnorePartialResultException(true);

        String filter = "(&" + cfg.getUserFilter() + "("
                + cfg.getLoginAttribute() + "=" + escape(username) + "))";

        List<DirContextOperations> found;
        try {
            found = tpl.search(
                    LdapQueryBuilder.query().base("").filter(filter),
                    (ContextMapper<DirContextOperations>) ctx -> (DirContextOperations) ctx);
        } catch (Exception e) {
            log.warn("Falha ao buscar usuário LDAP '{}': {}", username, e.getMessage());
            return Optional.empty();
        }
        if (found.isEmpty()) {
            return Optional.empty();
        }

        DirContextOperations entry = found.get(0);
        String userDn = entry.getDn().toString();
        String fullDn = userDn.isEmpty() ? cfg.getBaseDn() : userDn + "," + cfg.getBaseDn();

        // Valida a senha tentando um bind com o DN do usuário.
        DirContext test = null;
        try {
            test = contextSource.getContext(fullDn, rawPassword);
        } catch (Exception e) {
            return Optional.empty(); // credencial inválida
        } finally {
            LdapUtils.closeContext(test);
        }

        UUID guid = readGuid(entry);
        String email = firstNonBlank(entry.getStringAttribute("mail"),
                entry.getStringAttribute("userPrincipalName"));
        String nome = firstNonBlank(entry.getStringAttribute("displayName"),
                entry.getStringAttribute("cn"), username);
        String sam = firstNonBlank(entry.getStringAttribute(cfg.getLoginAttribute()), username);

        return Optional.of(new AuthenticatedUser(guid, sam, email, nome, "ad"));
    }

    private UUID readGuid(DirContextOperations entry) {
        Object raw = entry.getObjectAttribute("objectGUID");
        if (raw instanceof byte[] bytes && bytes.length == 16) {
            ByteBuffer bb = ByteBuffer.wrap(bytes);
            return new UUID(bb.getLong(), bb.getLong());
        }
        return null;
    }

    private static String firstNonBlank(String... values) {
        for (String v : values) {
            if (v != null && !v.isBlank()) return v;
        }
        return null;
    }

    /** Escapa metacaracteres de filtro LDAP (RFC 4515). */
    private static String escape(String input) {
        StringBuilder sb = new StringBuilder();
        for (char c : input.toCharArray()) {
            switch (c) {
                case '\\' -> sb.append("\\5c");
                case '*' -> sb.append("\\2a");
                case '(' -> sb.append("\\28");
                case ')' -> sb.append("\\29");
                case '\0' -> sb.append("\\00");
                default -> sb.append(c);
            }
        }
        return sb.toString();
    }
}
