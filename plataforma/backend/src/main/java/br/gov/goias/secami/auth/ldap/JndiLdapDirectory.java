package br.gov.goias.secami.auth.ldap;

import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.config.SecamiProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import javax.naming.AuthenticationException;
import javax.naming.Context;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.SizeLimitExceededException;
import javax.naming.directory.Attribute;
import javax.naming.directory.Attributes;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;
import javax.naming.directory.SearchControls;
import javax.naming.directory.SearchResult;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.Hashtable;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Autenticação contra o Active Directory via LDAPS (JNDI puro, sem
 * dependência extra). Fluxo: (1) bind com a conta de serviço; (2) busca o
 * usuário sob baseDn (só contas ativas, ver userFilter) — exige exatamente
 * UM resultado; (3) re-bind com o DN do usuário + a senha informada, que é
 * a validação real da credencial. A senha nunca é logada.
 *
 * <p>O certificado do DC é de uma CA interna (SEGPLANCA) — ela é importada no
 * truststore da imagem (ver Dockerfile do backend), então a verificação de
 * TLS e de hostname continua LIGADA, sem "trust all".
 */
@Component
@ConditionalOnProperty(name = "secami.ldap.enabled", havingValue = "true")
public class JndiLdapDirectory implements LdapDirectory {

    private static final Logger log = LoggerFactory.getLogger(JndiLdapDirectory.class);
    private static final int TAMANHO_MAXIMO_IDENTIFICADOR = 256;
    /** CPFs por consulta: OR de vários substrings numa varredura só (bem mais rápido que 1 consulta por CPF). */
    private static final int CPFS_POR_CONSULTA = 20;
    private static final Pattern CPF_NO_TEXTO = Pattern.compile("\\d{3}\\.?\\d{3}\\.?\\d{3}-?\\d{2}");

    private final SecamiProperties.Ldap cfg;

    public JndiLdapDirectory(SecamiProperties props) {
        this.cfg = props.getLdap();
    }

    @Override
    public LdapAuthResult authenticate(String identificador, String senha) {
        if (identificador == null || identificador.isBlank() || senha == null || senha.isBlank()
                || identificador.length() > TAMANHO_MAXIMO_IDENTIFICADOR) {
            // Senha vazia num bind simples vira bind ANÔNIMO e "funciona" —
            // nunca pode chegar no AD.
            return LdapAuthResult.naoEncontrado();
        }
        Entrada entrada = buscar(identificador.trim());
        if (entrada == null) {
            log.debug("LDAP: '{}' não encontrado (ou ambíguo) no AD.", identificador);
            return LdapAuthResult.naoEncontrado();
        }
        DirContext teste = null;
        try {
            teste = new InitialDirContext(ambiente(entrada.dn(), senha));
        } catch (AuthenticationException e) {
            log.info("LDAP: senha inválida pra '{}'.", entrada.usuario().samAccountName());
            return LdapAuthResult.senhaInvalida();
        } catch (NamingException e) {
            throw new LdapUnavailableException("Falha ao validar a senha no AD.", e);
        } finally {
            fechar(teste);
        }
        log.info("LDAP: '{}' autenticado no AD.", entrada.usuario().samAccountName());
        return LdapAuthResult.autenticado(entrada.usuario());
    }

    @Override
    public Map<String, List<LdapUser>> buscarPorCpfs(Collection<String> cpfs) {
        Map<String, List<LdapUser>> achados = new HashMap<>();
        List<String> todos = new ArrayList<>(new LinkedHashSet<>(cpfs));
        if (todos.isEmpty()) return achados;
        DirContext ctx = null;
        try {
            ctx = new InitialDirContext(ambiente(cfg.getBindDn(), cfg.getBindPassword(), cfg.getBulkReadTimeoutMs()));
            int totalLotes = (todos.size() + CPFS_POR_CONSULTA - 1) / CPFS_POR_CONSULTA;
            for (int i = 0; i < todos.size(); i += CPFS_POR_CONSULTA) {
                long inicio = System.currentTimeMillis();
                List<String> lote = todos.subList(i, Math.min(i + CPFS_POR_CONSULTA, todos.size()));
                SearchControls sc = new SearchControls();
                sc.setSearchScope(SearchControls.SUBTREE_SCOPE);
                sc.setTimeLimit(cfg.getBulkReadTimeoutMs());
                sc.setReturningAttributes(new String[] {
                        "sAMAccountName", "mail", "userPrincipalName", "displayName", "cn",
                        "objectGUID", cfg.getCpfAttribute()});
                NamingEnumeration<SearchResult> res = ctx.search(
                        cfg.getBaseDn(), montarFiltroPorCpfs(cfg.getUserFilter(), cfg.getCpfAttribute(), lote), sc);
                try {
                    while (res.hasMore()) {
                        LdapUser u = lerUsuario(res.next().getAttributes());
                        // o substring casa por texto solto: confere que o CPF extraído é mesmo um dos pedidos
                        if (u.cpf() != null && lote.contains(u.cpf())) {
                            achados.computeIfAbsent(u.cpf(), k -> new ArrayList<>()).add(u);
                        }
                    }
                } catch (SizeLimitExceededException e) {
                    log.warn("LDAP: limite de resultados atingido numa consulta de {} CPFs — resultado parcial.", lote.size());
                } finally {
                    res.close();
                }
                log.info("LDAP: lote {}/{} de CPFs consultado em {} ms ({} conta(s) achadas até agora).",
                        i / CPFS_POR_CONSULTA + 1, totalLotes, System.currentTimeMillis() - inicio, achados.size());
            }
            return achados;
        } catch (NamingException e) {
            throw new LdapUnavailableException("Falha ao consultar o AD por CPF.", e);
        } finally {
            fechar(ctx);
        }
    }

    private record Entrada(String dn, LdapUser usuario) {}

    /** @return a única entrada que casa com o identificador, ou null (nenhuma / ambígua). */
    private Entrada buscar(String identificador) {
        DirContext ctx = null;
        try {
            ctx = new InitialDirContext(ambiente(cfg.getBindDn(), cfg.getBindPassword()));
            SearchControls sc = new SearchControls();
            sc.setSearchScope(SearchControls.SUBTREE_SCOPE);
            sc.setCountLimit(3);
            sc.setTimeLimit(cfg.getReadTimeoutMs());
            sc.setReturningAttributes(new String[] {
                    "sAMAccountName", "mail", "userPrincipalName", "displayName", "cn",
                    "objectGUID", cfg.getCpfAttribute()});
            String filtro = montarFiltro(cfg.getUserFilter(), cfg.getLoginAttribute(), identificador);

            List<SearchResult> achados = new ArrayList<>();
            NamingEnumeration<SearchResult> res = ctx.search(cfg.getBaseDn(), filtro, sc);
            try {
                while (res.hasMore()) achados.add(res.next());
            } catch (SizeLimitExceededException e) {
                log.warn("LDAP: mais de um usuário casa com '{}' — recusado por ambiguidade.", identificador);
                return null;
            } finally {
                res.close();
            }
            if (achados.size() != 1) {
                if (achados.size() > 1) {
                    log.warn("LDAP: {} usuários casam com '{}' — recusado por ambiguidade.", achados.size(), identificador);
                }
                return null;
            }
            SearchResult r = achados.get(0);
            return new Entrada(r.getNameInNamespace(), lerUsuario(r.getAttributes()));
        } catch (NamingException e) {
            throw new LdapUnavailableException("Falha ao consultar o AD.", e);
        } finally {
            fechar(ctx);
        }
    }

    private Hashtable<String, Object> ambiente(String principal, String senha) {
        return ambiente(principal, senha, cfg.getReadTimeoutMs());
    }

    private Hashtable<String, Object> ambiente(String principal, String senha, int readTimeoutMs) {
        Hashtable<String, Object> env = new Hashtable<>();
        env.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
        env.put(Context.PROVIDER_URL, cfg.getUrl());
        env.put(Context.SECURITY_AUTHENTICATION, "simple");
        env.put(Context.SECURITY_PRINCIPAL, principal);
        env.put(Context.SECURITY_CREDENTIALS, senha);
        env.put(Context.REFERRAL, "ignore");
        env.put("java.naming.ldap.attributes.binary", "objectGUID");
        env.put("com.sun.jndi.ldap.connect.timeout", String.valueOf(cfg.getConnectTimeoutMs()));
        env.put("com.sun.jndi.ldap.read.timeout", String.valueOf(readTimeoutMs));
        return env;
    }

    private LdapUser lerUsuario(Attributes a) throws NamingException {
        String sam = texto(a, "sAMAccountName");
        String upn = texto(a, "userPrincipalName");
        String email = primeiroNaoVazio(texto(a, "mail"), upn);
        String nome = primeiroNaoVazio(texto(a, "displayName"), texto(a, "cn"), sam);
        return new LdapUser(lerGuid(a.get("objectGUID")), sam, email, nome,
                extrairCpf(texto(a, cfg.getCpfAttribute())));
    }

    private static String texto(Attributes a, String nome) throws NamingException {
        Attribute at = a.get(nome);
        Object v = at == null ? null : at.get();
        return v == null ? null : v.toString();
    }

    private static UUID lerGuid(Attribute at) throws NamingException {
        Object raw = at == null ? null : at.get();
        return raw instanceof byte[] bytes ? guidDeBytes(bytes) : null;
    }

    private static String primeiroNaoVazio(String... valores) {
        for (String v : valores) if (v != null && !v.isBlank()) return v;
        return null;
    }

    private static void fechar(DirContext ctx) {
        if (ctx == null) return;
        try {
            ctx.close();
        } catch (NamingException ignored) {
            // nada a fazer
        }
    }

    // ---- funções puras (package-visible pra teste unitário) ----

    /** Filtro final: userFilter AND (login por sAMAccountName, ou por UPN/e-mail se tiver "@"). */
    static String montarFiltro(String userFilter, String loginAttribute, String identificador) {
        String id = escaparFiltro(identificador);
        String criterio = identificador.contains("@")
                ? "(|(userPrincipalName=" + id + ")(mail=" + id + "))"
                : "(" + loginAttribute + "=" + id + ")";
        return "(&" + userFilter + criterio + ")";
    }

    /** userFilter AND (CPF em qualquer um dos formatos — "000.000.000-00" ou só dígitos —
     *  como substring do campo de texto livre). */
    static String montarFiltroPorCpfs(String userFilter, String cpfAttribute, List<String> cpfsEmDigitos) {
        StringBuilder ou = new StringBuilder("(|");
        for (String d : cpfsEmDigitos) {
            ou.append('(').append(cpfAttribute).append("=*").append(escaparFiltro(Cpf.format(d))).append("*)");
            ou.append('(').append(cpfAttribute).append("=*").append(escaparFiltro(d)).append("*)");
        }
        ou.append(')');
        return "(&" + userFilter + ou + ")";
    }

    /** Escapa metacaracteres de filtro LDAP (RFC 4515) — impede injeção de filtro. */
    static String escaparFiltro(String entrada) {
        StringBuilder sb = new StringBuilder();
        for (char c : entrada.toCharArray()) {
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

    /** O SGG guarda o CPF como texto livre no AD (ex.: "111.444.777-35") — pega o
     *  primeiro trecho que seja um CPF válido, em dígitos; null se não houver. */
    static String extrairCpf(String texto) {
        if (texto == null) return null;
        Matcher m = CPF_NO_TEXTO.matcher(texto);
        while (m.find()) {
            String digitos = Cpf.normalize(m.group());
            if (Cpf.isValid(digitos)) return digitos;
        }
        return null;
    }

    /** objectGUID do AD vem em formato misto (3 primeiros campos little-endian) —
     *  converte pro UUID canônico, o mesmo que as ferramentas do AD mostram. */
    static UUID guidDeBytes(byte[] b) {
        if (b == null || b.length != 16) return null;
        ByteBuffer le = ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN);
        long data1 = le.getInt() & 0xFFFFFFFFL;
        long data2 = le.getShort() & 0xFFFFL;
        long data3 = le.getShort() & 0xFFFFL;
        long msb = (data1 << 32) | (data2 << 16) | data3;
        long lsb = ByteBuffer.wrap(b, 8, 8).order(ByteOrder.BIG_ENDIAN).getLong();
        return new UUID(msb, lsb);
    }
}
