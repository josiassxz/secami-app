package br.gov.goias.secami.auth;

import br.gov.goias.secami.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Confere que o mecanismo de RBAC (roles no JWT → authorities → @PreAuthorize)
 * funciona ponta a ponta em controllers de OUTRAS áreas do sistema, não só nos
 * endpoints de auth/identity — pega uma amostra com políticas diferentes:
 * só-admin (JobsController), admin+professor (CoachController) e admin+gerente
 * (DepartmentController), além de uma rota de leitura sem restrição de papel
 * (autenticado basta) pra contrastar.
 */
class CrossControllerRbacTest extends AbstractIntegrationTest {

    // JobsController: @PreAuthorize("hasRole('ADMIN')") a nível de classe.

    @Test
    void jobsMarkAbsences_comoAdmin_retorna200() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/admin/jobs/mark-absences"), token))
                .andExpect(status().isOk());
    }

    @Test
    void jobsMarkAbsences_comoGerente_retorna403() throws Exception {
        // Gerente tem bastante poder em outras áreas (users, departments) mas
        // NÃO em jobs administrativos — confirma que não é "qualquer papel forte".
        String token = loginAs("gerente");
        mockMvc.perform(authed(post("/admin/jobs/mark-absences"), token))
                .andExpect(status().isForbidden());
    }

    // CoachController: GET /coach/students -> hasAnyRole('PROFESSOR','ADMIN')

    @Test
    void coachStudents_comoProfessor_retorna200() throws Exception {
        String token = loginAs("professor");
        mockMvc.perform(authed(get("/coach/students"), token))
                .andExpect(status().isOk());
    }

    @Test
    void coachStudents_comoAdmin_retorna200() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(get("/coach/students"), token))
                .andExpect(status().isOk());
    }

    @Test
    void coachStudents_comoAluno_retorna403() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/coach/students"), token))
                .andExpect(status().isForbidden());
    }

    // DepartmentController: GET é só autenticado; POST -> hasAnyRole('ADMIN','GERENTE')

    @Test
    void departmentsList_qualquerUsuarioAutenticado_retorna200() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/departments"), token))
                .andExpect(status().isOk());
    }

    @Test
    void departmentsCreate_comoGerente_retorna200() throws Exception {
        String token = loginAs("gerente");
        mockMvc.perform(authed(post("/departments"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Secretaria de Teste RBAC","sigla":"STR"}"""))
                .andExpect(status().isOk());
    }

    @Test
    void departmentsCreate_comoAluno_retorna403() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(post("/departments"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"Secretaria de Teste RBAC","sigla":"STR"}"""))
                .andExpect(status().isForbidden());
    }

    @Test
    void departmentsCreate_comoRecepcaoOuProfessor_retorna403() throws Exception {
        for (String sam : new String[] {"recepcao", "professor"}) {
            String token = loginAs(sam);
            mockMvc.perform(authed(post("/departments"), token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"name":"Secretaria de Teste RBAC","sigla":"STR"}"""))
                    .andExpect(status().isForbidden());
        }
    }
}
