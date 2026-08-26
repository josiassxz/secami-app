package br.gov.goias.secami;

import org.junit.jupiter.api.Test;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

class SmokeTest extends AbstractIntegrationTest {

    @Test
    void loginAdminEAcessaRotaProtegida() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(get("/me"), token)).andExpect(status().isOk());
    }

    @Test
    void rotaProtegidaSemTokenRetorna401() throws Exception {
        mockMvc.perform(get("/me")).andExpect(status().isUnauthorized());
    }

    @Test
    void rotaProtegidaComTokenInvalidoRetorna401() throws Exception {
        mockMvc.perform(authed(get("/me"), "token.invalido.qualquer"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void rotaAdminComUsuarioSemPapelRetorna403() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(post("/admin/jobs/mark-absences"), token))
                .andExpect(status().isForbidden());
    }
}
