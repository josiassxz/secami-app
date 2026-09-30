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
    private Accelero accelero = new Accelero();
    private Ldap ldap = new Ldap();
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

    /** Catracas da academia (sistema Accelero). Desligado por padrão — só liga
     *  em ambientes com rede até o Accelero (não alcançável em dev/teste). */
    @Data
    public static class Accelero {
        private boolean enabled = false;
        private String baseUrl = "https://10.5.150.8";
        private String usuario;
        private String senha;
        /** pctID da categoria única que libera entrada e saída na catraca da
         *  academia — militar vitalícia, civil por agendamento. */
        private String categoriaAcessoId = "1213819408";
    }

    /** Login com a conta do governo (Active Directory via LDAPS), como
     *  alternativa à senha local. Desligado por padrão — só liga em ambiente
     *  com rede até o DC (não alcançável em dev/teste). A senha da conta de
     *  serviço vem SEMPRE de env/secret manager, nunca versionada. */
    @Data
    public static class Ldap {
        private boolean enabled = false;
        /** Ex.: ldaps://dc2-dcsrv05.goias.intra:636 */
        private String url;
        private String baseDn;
        /** Conta de serviço usada só pra BUSCAR o usuário (UPN ou DN). */
        private String bindDn;
        private String bindPassword;
        private String loginAttribute = "sAMAccountName";
        /** Só contas ativas de pessoas (exclui desabilitadas). */
        private String userFilter =
                "(&(objectClass=user)(objectCategory=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))";
        /** Atributo do AD onde o SGG guarda o CPF do servidor (texto livre, ex. "111.444.777-35"). */
        private String cpfAttribute = "description";
        private int connectTimeoutMs = 5000;
        private int readTimeoutMs = 8000;
        /** Consulta em lote por CPF varre a OU inteira (substring em campo sem índice) — precisa de bem mais tempo que um login. */
        private int bulkReadTimeoutMs = 180000;
        /** Falhas de bind por identificador antes de bloquear novas tentativas (protege contra bloqueio de conta no AD). */
        private int maxFailedAttempts = 4;
        private int lockoutMinutes = 15;
    }
}
