package br.gov.goias.secami.auth;

import br.gov.goias.secami.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * POST /auth/login: credenciais corretas emitem tokens + roles corretas por usuário;
 * credenciais erradas (senha errada ou usuário inexistente) falham com a mesma
 * mensagem genérica (AuthService.login, ver comentário lá — não vaza se o usuário
 * existe ou não); payload inválido é rejeitado por bean validation.
 */
class LoginTest extends AbstractIntegrationTest {

    @Test
    void loginAdmin_retornaTokensERolePapelAdmin() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"admin@dev.secami","password":"secami123"}""")
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresIn").isNumber())
                .andExpect(jsonPath("$.roles", org.hamcrest.Matchers.contains("admin")));
    }

    @Test
    void loginAluno_retornaTokensERolePapelAluno() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"aluno@dev.secami","password":"secami123"}""")
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isNotEmpty())
                .andExpect(jsonPath("$.refreshToken").isNotEmpty())
                .andExpect(jsonPath("$.roles", org.hamcrest.Matchers.contains("aluno")));
    }

    @Test
    void loginSenhaErrada_retorna422ComMensagemDeCredencialInvalida() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"admin@dev.secami","password":"senha-errada"}""")
                )
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("E-mail/usuário ou senha inválidos."));
    }

    @Test
    void loginUsuarioInexistente_retorna422ComMensagemDeCredencialInvalida() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"usuario-que-nao-existe@dev.secami","password":"qualquer"}""")
                )
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("E-mail/usuário ou senha inválidos."));
    }

    @Test
    void loginComCamposEmBranco_retorna400DeValidacao() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"email":"","password":""}""")
                )
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors", org.hamcrest.Matchers.hasSize(2)));
    }
}
