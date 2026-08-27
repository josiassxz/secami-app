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
    private DevAuth devAuth = new DevAuth();
    private Cors cors = new Cors();
    private Storage storage = new Storage();
    private String timezone = "America/Sao_Paulo";

    @Data
    public static class Jwt {
        private String secret;
        private int accessTokenMinutes = 15;
        private int refreshTokenDays = 7;
        private String issuer = "secami-backend";
    }

    @Data
    public static class DevAuth {
        /** Quando true, semeia os usuários locais de desenvolvimento. */
        private boolean enabled = true;
    }

    @Data
    public static class Storage {
        /** Diretório local onde ficam os arquivos enviados (atestados, fotos). */
        private String basePath = "./uploads";
        private long maxFileSizeMb = 10;
    }

    @Data
    public static class Cors {
        private List<String> allowedOrigins = List.of("http://localhost:5173");
    }
}
