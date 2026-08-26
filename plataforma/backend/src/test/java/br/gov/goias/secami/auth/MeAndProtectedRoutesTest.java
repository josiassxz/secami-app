package br.gov.goias.secami.auth;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.config.SecamiProperties;
import br.gov.goias.secami.identity.AppUserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.List;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GET /me e o contrato 401-vs-403 em rotas protegidas em geral.
 *
 * <p>Distinção crítica corrigida em SecurityConfig (ver comentário lá): "sem
 * credencial utilizável" (token ausente, malformado, expirado, tipo errado) tem
 * que ser SEMPRE 401 — é o sinal que os dois clientes REST (admin React e app
 * Flutter) usam pra disparar o refresh automático de token. "Autenticado mas sem
 * o papel exigido" continua 403 (AccessDeniedHandler), que os clientes tratam como
 * falta de permissão, não como sessão expirada. Misturar os dois faria o usuário
 * ser deslogado à toa (403 tratado como sessão morta) ou nunca renovar o token
 * (token expirado devolvendo 403 ao invés de 401).
 */
class MeAndProtectedRoutesTest extends AbstractIntegrationTest {

    @Autowired private SecamiProperties secamiProperties;
    @Autowired private AppUserRepository users;

    private JwtTestSupport jwtTestSupport() {
        return new JwtTestSupport(secamiProperties);
    }

    @Test
    void meSemToken_retorna401() throws Exception {
        mockMvc.perform(get("/me")).andExpect(status().isUnauthorized());
    }

    @Test
    void meComTokenValido_retorna200ComDadosDoUsuarioLogado() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(get("/me"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.samAccountName").value("admin"))
                .andExpect(jsonPath("$.nome").value("Administrador SECAMI"))
                .andExpect(jsonPath("$.ativo").value(true))
                .andExpect(jsonPath("$.roles", org.hamcrest.Matchers.contains("admin")));
    }

    @Test
    void meComTokenDeOutroUsuario_retornaDadosDaquelePapel() throws Exception {
        String token = loginAs("professor");
        mockMvc.perform(authed(get("/me"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.samAccountName").value("professor"))
                .andExpect(jsonPath("$.roles", org.hamcrest.Matchers.contains("professor")));
    }

    @Test
    void meComTokenMalformado_retorna401NaoRetorna403() throws Exception {
        mockMvc.perform(authed(get("/me"), "isto-nao-e-um-jwt"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void meComTokenExpirado_retorna401NaoRetorna403() throws Exception {
        UUID adminId = users.findBySamAccountNameIgnoreCase("admin").orElseThrow().getId();
        String expired = jwtTestSupport().expiredAccessToken(adminId, List.of("admin"));

        mockMvc.perform(authed(get("/me"), expired))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void meComTokenAssinaturaInvalida_retorna401() throws Exception {
        UUID adminId = users.findBySamAccountNameIgnoreCase("admin").orElseThrow().getId();
        String adulterado = jwtTestSupport().tokenComAssinaturaInvalida(adminId);

        mockMvc.perform(authed(get("/me"), adulterado))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void meComRefreshTokenNoLugarDeAccessToken_retorna401() throws Exception {
        // JwtAuthFilter só autentica claims com type=access; um refreshToken válido
        // (assinatura e issuer corretos) não deve autenticar rota nenhuma.
        String loginResponse = mockMvc.perform(post("/auth/login")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"admin","password":"secami123"}"""))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        String refreshToken = objectMapper.readTree(loginResponse).get("refreshToken").asText();

        mockMvc.perform(authed(get("/me"), refreshToken))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void rotaProtegidaComUsuarioAutenticadoMasSemPapelExigido_retorna403NaoRetorna401() throws Exception {
        // Contraste com os testes acima: aqui a credencial É válida (aluno está
        // legitimamente autenticado), só falta o papel — isso é 403, não 401.
        String token = loginAs("aluno");
        mockMvc.perform(authed(post("/admin/jobs/mark-absences"), token))
                .andExpect(status().isForbidden());
    }
}
