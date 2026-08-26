package br.gov.goias.secami.auth;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.identity.AppUserRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GET /users e PATCH /users/{id}/roles (UserController) — gestão de papéis é
 * privilégio de admin; listagem é admin+gerente.
 */
class UserRolesRbacTest extends AbstractIntegrationTest {

    @Autowired private AppUserRepository users;

    private UUID alunoId() {
        return users.findBySamAccountNameIgnoreCase("aluno").orElseThrow().getId();
    }

    @Test
    void listUsers_comoAdmin_retorna200() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(get("/users"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", org.hamcrest.Matchers.hasSize(5)));
    }

    @Test
    void listUsers_comoGerente_retorna200() throws Exception {
        String token = loginAs("gerente");
        mockMvc.perform(authed(get("/users"), token))
                .andExpect(status().isOk());
    }

    @Test
    void listUsers_comoAlunoOuProfessorOuRecepcao_retorna403() throws Exception {
        for (String sam : new String[] {"aluno", "professor", "recepcao"}) {
            String token = loginAs(sam);
            mockMvc.perform(authed(get("/users"), token))
                    .andExpect(status().isForbidden());
        }
    }

    @Test
    void listUsers_semToken_retorna401() throws Exception {
        mockMvc.perform(get("/users")).andExpect(status().isUnauthorized());
    }

    @Test
    void updateRoles_comoAdmin_atualizaPapeisEPersiste() throws Exception {
        String token = loginAs("admin");
        UUID id = alunoId();

        mockMvc.perform(authed(patch("/users/{id}/roles", id), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"roles":["aluno","recepcao"]}"""))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.roles", org.hamcrest.Matchers.containsInAnyOrder("aluno", "recepcao")));

        // Persistiu de verdade (não é só o retorno do endpoint).
        var reloaded = users.findById(id).orElseThrow();
        org.assertj.core.api.Assertions.assertThat(reloaded.getRoles())
                .containsExactlyInAnyOrder("aluno", "recepcao");
    }

    @Test
    void updateRoles_comoGerente_retorna403() throws Exception {
        String token = loginAs("gerente");
        mockMvc.perform(authed(patch("/users/{id}/roles", alunoId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"roles":["admin"]}"""))
                .andExpect(status().isForbidden());
    }

    @Test
    void updateRoles_comoAluno_retorna403() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(patch("/users/{id}/roles", alunoId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"roles":["admin"]}"""))
                .andExpect(status().isForbidden());
    }

    @Test
    void updateRoles_semToken_retorna401() throws Exception {
        mockMvc.perform(patch("/users/{id}/roles", alunoId())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"roles":["admin"]}"""))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void updateRoles_comPapelInvalido_retorna422() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(patch("/users/{id}/roles", alunoId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"roles":["super-admin-inexistente"]}"""))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Papel inválido: super-admin-inexistente"));
    }

    @Test
    void updateRoles_comUsuarioInexistente_retorna404() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(patch("/users/{id}/roles", UUID.randomUUID()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"roles":["aluno"]}"""))
                .andExpect(status().isNotFound());
    }
}
