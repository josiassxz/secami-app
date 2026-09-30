package br.gov.goias.secami.accelero;

import br.gov.goias.secami.accelero.AcceleroDtos.CategoriaVinculada;
import br.gov.goias.secami.accelero.AcceleroDtos.EventoAcesso;
import br.gov.goias.secami.accelero.AcceleroDtos.IdentificadorVinculado;
import br.gov.goias.secami.accelero.AcceleroDtos.PaginaEventos;
import br.gov.goias.secami.accelero.AcceleroDtos.PessoaEncontrada;
import br.gov.goias.secami.config.SecamiProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLParameters;
import javax.net.ssl.X509ExtendedTrustManager;
import java.net.CookieManager;
import java.net.CookiePolicy;
import java.net.http.HttpClient;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Implementação real do {@link AcceleroClient} — HTTP puro (sem SDK), a
 * mesma API AJAX que o painel web do Accelero usa (sessão PHPSESSID +
 * signature raspado da página da pessoa). Ver {@code accelero/accelero.py}
 * na raiz do projeto: este cliente é uma porta fiel daquele, adaptada a um
 * processo de longa duração (a sessão fica em memória, sem precisar de
 * arquivo+lock entre execuções).
 *
 * <p>O host do Accelero usa certificado autoassinado — aceitamos qualquer
 * certificado (equivalente ao {@code curl -k} do script original) só para
 * este host interno específico, nunca para chamadas de saída em geral.
 */
public class HttpAcceleroClient implements AcceleroClient {

    private static final Logger log = LoggerFactory.getLogger(HttpAcceleroClient.class);
    private static final Pattern SIGNATURE_PATTERN = Pattern.compile("\"signature\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern TOTAL_PAGINAS_PATTERN = Pattern.compile("Table\\.paginate\\((\\d+)");

    private final RestClient http;
    private final CookieManager cookieManager;
    private final SecamiProperties.Accelero config;
    private final ObjectMapper mapper = new ObjectMapper();
    private final Object sessionLock = new Object();

    public HttpAcceleroClient(SecamiProperties.Accelero config) {
        this.config = config;
        this.cookieManager = new CookieManager(null, CookiePolicy.ACCEPT_ALL);
        // "" desliga a verificação de hostname do certificado — junto com o
        // trust manager permissivo abaixo, equivale ao `verify=False` do
        // cliente Python / `curl -k` (host interno com certificado autoassinado).
        SSLParameters semVerificacaoDeHostname = new SSLParameters();
        semVerificacaoDeHostname.setEndpointIdentificationAlgorithm("");
        HttpClient jdkClient = HttpClient.newBuilder()
                .cookieHandler(cookieManager)
                .sslContext(trustAllSslContext())
                .sslParameters(semVerificacaoDeHostname)
                .connectTimeout(Duration.ofSeconds(15))
                .build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(jdkClient);
        factory.setReadTimeout(Duration.ofSeconds(30));
        this.http = RestClient.builder()
                .baseUrl(config.getBaseUrl())
                .requestFactory(factory)
                .build();
    }

    // ---------- sessão ----------

    /** Garante uma sessão válida antes de qualquer chamada (login só se preciso). */
    private void ensureSession() {
        if (sessaoValida()) return;
        synchronized (sessionLock) {
            if (sessaoValida()) return; // outra thread pode ter logado enquanto esperávamos o lock
            login();
        }
    }

    private boolean sessaoValida() {
        if (!temCookiePhpSessId()) return false;
        try {
            // postJson já lança se "code" != 200 — chegar aqui sem exceção basta.
            postJson("/categorias/selectlist", null, null, null, null);
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private void login() {
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("usuario", config.getUsuario());
        form.add("password", config.getSenha());
        form.add("deviceid", "");
        form.add("route", "");
        try {
            http.post()
                    .uri(b -> b.path("/login").queryParam("d", "true").build())
                    .headers(h -> {
                        h.set("x-requested-with", "XMLHttpRequest");
                        h.set(HttpHeaders.ORIGIN, config.getBaseUrl());
                        h.set(HttpHeaders.REFERER, config.getBaseUrl() + "/index");
                    })
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(form)
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception e) {
            throw new AcceleroException("Falha ao conectar no Accelero para login.", e);
        }
        if (!temCookiePhpSessId()) {
            throw new AcceleroException("Login no Accelero falhou (sem PHPSESSID na resposta).");
        }
        log.info("Novo login realizado no Accelero.");
    }

    private boolean temCookiePhpSessId() {
        return cookieManager.getCookieStore().getCookies().stream()
                .anyMatch(c -> "PHPSESSID".equals(c.getName()));
    }

    // ---------- helpers ----------

    @Override
    public AcceleroDtos.PessoaDetalhe detalharPessoa(String pessoaId) {
        ensureSession();
        String html = paginaPessoa(pessoaId);
        JsonNode json = extrairJsonPessoa(html, mapper);
        if (json == null) {
            throw new AcceleroException("Não foi possível ler os dados cadastrais da pessoa " + pessoaId + ".");
        }
        return new AcceleroDtos.PessoaDetalhe(
                textoOuNulo(json, "pesID"), textoOuNulo(json, "pesNome"),
                textoOuNulo(json, "pesEmail"), textoOuNulo(json, "pesDocumento"));
    }

    /** O JSON com os dados da pessoa vem embutido num {@code <script>} que
     *  pré-popula o formulário de edição (não tem endpoint AJAX dedicado) —
     *  ex.: {@code DataHandler.populate(container, {"uid":"...","pesEmail":...});}.
     *  Localiza o objeto pelo marcador e extrai pelo balanceamento de chaves
     *  (respeitando strings) em vez de regex, já que o JSON tem campos que
     *  são, eles mesmos, JSON serializado como string (ex.: pesMetadata).
     *  Estático + package-visible pra dar pra testar sem precisar de sessão
     *  HTTP real (ver HttpAcceleroClientTest). */
    static JsonNode extrairJsonPessoa(String html, ObjectMapper mapper) {
        if (html == null) return null;
        int marcador = html.indexOf("DataHandler.populate(container,");
        if (marcador < 0) return null;
        int abre = html.indexOf('{', marcador);
        if (abre < 0) return null;
        int profundidade = 0;
        boolean dentroDeString = false;
        boolean escapando = false;
        int i = abre;
        for (; i < html.length(); i++) {
            char c = html.charAt(i);
            if (escapando) {
                escapando = false;
            } else if (c == '\\') {
                escapando = true;
            } else if (c == '"') {
                dentroDeString = !dentroDeString;
            } else if (!dentroDeString) {
                if (c == '{') profundidade++;
                else if (c == '}') {
                    profundidade--;
                    if (profundidade == 0) {
                        i++;
                        break;
                    }
                }
            }
        }
        try {
            return mapper.readTree(html.substring(abre, i));
        } catch (Exception e) {
            return null;
        }
    }

    private String paginaPessoa(String pessoaId) {
        try {
            return http.get()
                    .uri("/pessoas/{id}", pessoaId)
                    .header("x-requested-with", "XMLHttpRequest")
                    .retrieve()
                    .body(String.class);
        } catch (Exception e) {
            throw new AcceleroException("Falha ao carregar a página da pessoa " + pessoaId + ".", e);
        }
    }

    private String signaturePessoa(String pessoaId) {
        String page = paginaPessoa(pessoaId);
        Matcher m = SIGNATURE_PATTERN.matcher(page == null ? "" : page);
        if (!m.find()) {
            throw new AcceleroException("signature não encontrado na página da pessoa " + pessoaId + ".");
        }
        return m.group(1).replace("\\/", "/");
    }

    private JsonNode postJson(String path, String signature, MultiValueMap<String, String> body,
                               MultiValueMap<String, String> extraParams, String referer) {
        RestClient.RequestBodySpec req = http.post()
                .uri(b -> {
                    b.path(path).queryParam("d", "true");
                    if (signature != null) b.queryParam("signature", signature);
                    if (extraParams != null) extraParams.forEach((k, vs) -> vs.forEach(v -> b.queryParam(k, v)));
                    return b.build();
                })
                .header("x-requested-with", "XMLHttpRequest")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED);
        if (referer != null) {
            req = req.header(HttpHeaders.ORIGIN, config.getBaseUrl()).header(HttpHeaders.REFERER, referer);
        }

        String raw;
        try {
            raw = req.body(body == null ? new LinkedMultiValueMap<>() : body)
                    .retrieve()
                    .body(String.class);
        } catch (org.springframework.web.client.RestClientResponseException e) {
            // RestClient lança isso pra qualquer status não-2xx — sem isso, um
            // erro do PRÓPRIO Accelero (400/403/500 etc.) ficava indistinguível
            // de uma falha de rede, escondendo a causa real.
            throw new AcceleroException("Accelero respondeu HTTP " + e.getStatusCode().value() + " em "
                    + path + ": " + truncar(e.getResponseBodyAsString()), e);
        } catch (Exception e) {
            throw new AcceleroException("Falha de comunicação com o Accelero em " + path + ": "
                    + e.getClass().getSimpleName() + " — " + e.getMessage(), e);
        }
        JsonNode obj;
        try {
            obj = mapper.readTree(raw);
        } catch (Exception e) {
            throw new AcceleroException("Resposta inesperada do Accelero em " + path + ": "
                    + truncar(raw));
        }
        if (obj.path("code").asInt() != 200) {
            throw new AcceleroException("Erro do Accelero em " + path + ": " + truncar(obj.toString()));
        }
        return obj;
    }

    private static String truncar(String s) {
        if (s == null) return "";
        return s.length() > 500 ? s.substring(0, 500) : s;
    }

    // ---------- API pública ----------

    @Override
    public List<PessoaEncontrada> pesquisarPessoas(String filtro) {
        ensureSession();
        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("filter", filtro);
        params.add("search", "1");
        params.add("page", "1");
        JsonNode obj = postJson("/pessoas/pesquisaRapida", null, null, params, null);
        List<PessoaEncontrada> out = new ArrayList<>();
        for (JsonNode row : obj.path("msg")) {
            out.add(new PessoaEncontrada(
                    textoOuNulo(row, "UID"),
                    textoOuNulo(row, "pesNome"),
                    primeiroCampoNaoVazio(row, "pesCPF", "pesCpf", "pesCPFCNPJ", "pesCpfCnpj", "cpf")));
        }
        return out;
    }

    @Override
    public List<CategoriaVinculada> listarCategorias(String pessoaId) {
        ensureSession();
        String sig = signaturePessoa(pessoaId);
        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("page", "1");
        JsonNode obj = postJson("/pessoas/" + pessoaId + "/categorias", sig, null, params, null);
        List<CategoriaVinculada> out = new ArrayList<>();
        for (JsonNode row : obj.path("msg")) {
            out.add(new CategoriaVinculada(
                    textoOuNulo(row, "UID"),
                    textoOuNulo(row, "pctID"),
                    textoOuNulo(row, "pctDescricao")));
        }
        return out;
    }

    @Override
    public void adicionarCategoria(String pessoaId, String categoriaId, String inicio, String fim) {
        ensureSession();
        String sig = signaturePessoa(pessoaId);
        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("pctID", categoriaId);
        body.add("lpcDateStart", inicio == null ? "" : inicio);
        body.add("lpcDateEnd", fim == null ? "" : fim);
        postJson("/pessoas/" + pessoaId + "/adicionarCategoria", sig, body, null,
                config.getBaseUrl() + "/pessoas/" + pessoaId);
    }

    @Override
    public void excluirCategoria(String pessoaId, String vinculoUid) {
        ensureSession();
        String sig = signaturePessoa(pessoaId);
        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("values[]", vinculoUid);
        postJson("/pessoas/" + pessoaId + "/excluirCategorias", sig, body, null,
                config.getBaseUrl() + "/pessoas/" + pessoaId);
    }

    @Override
    public List<IdentificadorVinculado> listarIdentificadores(String pessoaId) {
        ensureSession();
        String sig = signaturePessoa(pessoaId);
        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("page", "1");
        JsonNode obj = postJson("/pessoas/" + pessoaId + "/identificadores", sig, null, params, null);
        List<IdentificadorVinculado> out = new ArrayList<>();
        for (JsonNode row : obj.path("msg")) {
            Integer habilitado = row.hasNonNull("carHabilitado") ? row.get("carHabilitado").asInt() : null;
            out.add(new IdentificadorVinculado(textoOuNulo(row, "UID"), textoOuNulo(row, "ctpDescricao"), habilitado));
        }
        return out;
    }

    @Override
    public void desassociarIdentificador(String pessoaId, String vinculoUid, Integer carHabilitado) {
        ensureSession();
        String sig = signaturePessoa(pessoaId);
        MultiValueMap<String, String> body = new LinkedMultiValueMap<>();
        body.add("carHabilitado", String.valueOf(carHabilitado == null ? 1 : carHabilitado));
        postJson("/pessoas/" + pessoaId + "/identificadores/" + vinculoUid + "/desassociar", sig, body, null,
                config.getBaseUrl() + "/pessoas/" + pessoaId);
    }

    @Override
    public PaginaEventos listarLogEventos(String pessoaId, String dataInicial, String dataFinal, int page) {
        ensureSession();
        String sig = signaturePessoa(pessoaId);
        MultiValueMap<String, String> params = new LinkedMultiValueMap<>();
        params.add("search", "1");
        params.add("page", String.valueOf(page));
        if (dataInicial != null && !dataInicial.isBlank()) params.add("relDataInicial", dataInicial);
        if (dataFinal != null && !dataFinal.isBlank()) params.add("relDataFinal", dataFinal);
        JsonNode obj = postJson("/pessoas/" + pessoaId + "/logeventos", sig, null, params, null);

        List<EventoAcesso> eventos = new ArrayList<>();
        for (JsonNode row : obj.path("msg")) {
            eventos.add(new EventoAcesso(
                    textoOuNulo(row, "levDataHora"),
                    textoOuNulo(row, "conDescricao"),
                    textoOuNulo(row, "areDescricao"),
                    textoOuNulo(row, "letDescricao"),
                    row.hasNonNull("letStatus") ? row.get("letStatus").asInt() : null,
                    textoOuNulo(row, "carNumero")));
        }
        Matcher m = TOTAL_PAGINAS_PATTERN.matcher(obj.path("f").asText(""));
        int totalPaginas = m.find() ? Math.max(1, Integer.parseInt(m.group(1))) : 1;
        return new PaginaEventos(eventos, totalPaginas);
    }

    // ---------- parsing defensivo (campos exatos ainda não confirmados contra o Accelero real) ----------

    private static String textoOuNulo(JsonNode row, String campo) {
        JsonNode v = row.get(campo);
        return (v == null || v.isNull()) ? null : v.asText();
    }

    private static String primeiroCampoNaoVazio(JsonNode row, String... campos) {
        for (String campo : campos) {
            String v = textoOuNulo(row, campo);
            if (v != null && !v.isBlank()) return v;
        }
        return null;
    }

    // ---------- TLS (certificado autoassinado do Accelero) ----------

    private static SSLContext trustAllSslContext() {
        try {
            SSLContext ctx = SSLContext.getInstance("TLS");
            ctx.init(null, new javax.net.ssl.TrustManager[]{new X509ExtendedTrustManager() {
                public void checkClientTrusted(X509Certificate[] c, String a) {}
                public void checkServerTrusted(X509Certificate[] c, String a) {}
                public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
                public void checkClientTrusted(X509Certificate[] c, String a, java.net.Socket s) {}
                public void checkServerTrusted(X509Certificate[] c, String a, java.net.Socket s) {}
                public void checkClientTrusted(X509Certificate[] c, String a, javax.net.ssl.SSLEngine e) {}
                public void checkServerTrusted(X509Certificate[] c, String a, javax.net.ssl.SSLEngine e) {}
            }}, new SecureRandom());
            return ctx;
        } catch (Exception e) {
            throw new AcceleroException("Falha ao preparar TLS para o Accelero.", e);
        }
    }
}
