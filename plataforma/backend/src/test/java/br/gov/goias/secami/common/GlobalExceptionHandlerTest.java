package br.gov.goias.secami.common;

import br.gov.goias.secami.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Erros causados pela requisição (JSON quebrado, parâmetro inválido, rota/
 * método inexistente) precisam voltar como 4xx JSON com mensagem em pt-BR —
 * não como "500 Erro interno" nem como página HTML/stack.
 */
class GlobalExceptionHandlerTest extends AbstractIntegrationTest {

    @Test
    void jsonMalFormado_retorna400ComMensagemAmigavel() throws Exception {
        mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\": "))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", containsString("Requisição inválida")))
                .andExpect(content().string(not(containsString("JsonParseException"))));
    }

    @Test
    void parametroDeDataInvalido_retorna400() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/me/appointments/available").param("date", "nao-e-data"), token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Parâmetro inválido ou ausente na requisição."));
    }

    @Test
    void parametroObrigatorioAusente_retorna400() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/me/appointments/available"), token))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Parâmetro inválido ou ausente na requisição."));
    }

    @Test
    void rotaInexistente_retorna404Json() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(get("/rota-que-nao-existe"), token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.message").value("Recurso não encontrado."));
    }

    @Test
    void metodoNaoPermitido_retorna405() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/me"), token))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(jsonPath("$.message").value("Operação não permitida para este recurso."));
    }
}
