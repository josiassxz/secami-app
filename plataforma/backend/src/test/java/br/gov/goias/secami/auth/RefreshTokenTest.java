package br.gov.goias.secami.auth;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.config.SecamiProperties;
import br.gov.goias.secami.identity.AppUserRepository;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * POST /auth/refresh: com refreshToken válido emite um novo accessToken utilizável;
 * rejeita tokens do tipo errado (um accessToken passado no lugar de refreshToken),
 * malformados e expirados.
 */
class RefreshTokenTest extends AbstractIntegrationTest {

    @Autowired private SecamiProperties secamiProperties;
    @Autowired private AppUserRepository users;

    private JwtTestSupport jwtTestSupport() {
        return new JwtTestSupport(secamiProperties);
    }

    @Test
    void refreshComTokenValido_geraNovoAccessTokenFuncional() throws Exception {
        String loginResponse = mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"admin@dev.secami","password":"secami123"}"""))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        JsonNode node = objectMapper.readTree(loginResponse);
        String refreshToken = node.get("refreshToken").asText();
        String oldAccessToken = node.get("accessToken").asText();

        String refreshResponse = mockMvc.perform(post("/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshBody(refreshToken))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.roles", org.hamcrest.Matchers.contains("admin")))
                .andReturn().getResponse().getContentAsString();
        String newAccessToken = objectMapper.readTree(refreshResponse).get("accessToken").asText();

        // O novo accessToken precisa funcionar de verdade numa rota protegida.
        mockMvc.perform(authed(get("/me"), newAccessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.samAccountName").value("admin"));

        // Sanidade: o token velho (ainda válido, não expirado) também continua ok —
        // refresh não é revogação de sessão neste sistema (stateless, ver AuthController.logout).
        mockMvc.perform(authed(get("/me"), oldAccessToken)).andExpect(status().isOk());
    }

    @Test
    void refreshComAccessTokenNoLugarDeRefreshToken_retornaErro() throws Exception {
        String accessToken = loginAs("admin");

        mockMvc.perform(post("/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshBody(accessToken))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Token de refresh inválido."));
    }

    @Test
    void refreshComTokenMalformado_retornaErro() throws Exception {
        mockMvc.perform(post("/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshBody("token.invalido.qualquer"))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Token de refresh inválido ou expirado."));
    }

    @Test
    void refreshComTokenExpirado_retornaErro() throws Exception {
        UUID adminId = users.findBySamAccountNameIgnoreCase("admin").orElseThrow().getId();
        String expired = jwtTestSupport().expiredRefreshToken(adminId);

        mockMvc.perform(post("/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new RefreshBody(expired))))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Token de refresh inválido ou expirado."));
    }

    @Test
    void refreshComCorpoVazio_retorna400DeValidacao() throws Exception {
        mockMvc.perform(post("/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":""}"""))
                .andExpect(status().isBadRequest());
    }

    private record RefreshBody(String refreshToken) {}
}
