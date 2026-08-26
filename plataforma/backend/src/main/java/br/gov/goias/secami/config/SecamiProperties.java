package br.gov.goias.secami.config;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

/**
 * Configuração tipada da aplicação (prefixo {@code secami} em application.yml).
 */
@Data
@ConfigurationProperties(prefix = "secami")
public class SecamiProperties {

    private Jwt jwt = new Jwt();
    private Ldap ldap = new Ldap();
    private DevAuth devAuth = new DevAuth();
    private Cors cors = new Cors();
    private String timezone = "America/Sao_Paulo";

    @Data
    public static class Jwt {
        private String secret;
        private int accessTokenMinutes = 15;
        private int refreshTokenDays = 7;
        private String issuer = "secami-backend";
    }

    @Data
    public static class Ldap {
        private boolean enabled = false;
        private String host;
        private int port = 636;
        private boolean ssl = true;
        private String baseDn;
        private String bindDn;
        private String bindPassword;
        private String loginAttribute = "samAccountName";
        private String syncAttribute = "objectGUID";
        private String userFilter;

        /** URL LDAPS/LDAP montada a partir de host/porta/ssl. */
        public String url() {
            return (ssl ? "ldaps://" : "ldap://") + host + ":" + port;
        }
    }

    @Data
    public static class DevAuth {
        /** Quando true e LDAP desabilitado, autentica contra usuários locais semeados. */
        private boolean enabled = true;
    }

    @Data
    public static class Cors {
        private List<String> allowedOrigins = List.of("http://localhost:5173");
    }
}
