package br.gov.goias.secami.academy.cadastros;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.department.Department;
import br.gov.goias.secami.academy.department.DepartmentDtos.UpsertRequest;
import br.gov.goias.secami.academy.department.DepartmentRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Testes de integração de /departments (CRUD de secretarias/órgãos). SPEC §9.3, §11.1.
 */
class DepartmentCadastroTest extends AbstractIntegrationTest {

    @Autowired DepartmentRepository departments;

    @Test
    void criarSecretariaComoAdmin_retorna200() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/departments"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpsertRequest("Secretaria de Teste", "SEC-T", "3º andar", null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Secretaria de Teste"))
                .andExpect(jsonPath("$.sigla").value("SEC-T"))
                .andExpect(jsonPath("$.andar").value("3º andar"))
                .andExpect(jsonPath("$.active").value(true));
    }

    @Test
    void criarSecretariaComoGerente_retorna200() throws Exception {
        String token = loginAs("gerente");
        mockMvc.perform(authed(post("/departments"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpsertRequest("Outra Secretaria", null, null, null))))
                .andExpect(status().isOk());
    }

    @Test
    void criarSecretariaSemNome_retorna400() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/departments"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpsertRequest("", null, null, null))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors[?(@.field=='name')]").exists());
    }

    @Test
    void editarSecretariaComoGerente_atualizaCampos() throws Exception {
        Department d = saveDepartment("Nome Original");
        String token = loginAs("gerente");

        mockMvc.perform(authed(put("/departments/" + d.getId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpsertRequest("Nome Atualizado", "AT", "1º andar", false))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Nome Atualizado"))
                .andExpect(jsonPath("$.sigla").value("AT"))
                .andExpect(jsonPath("$.active").value(false));

        assertThat(departments.findById(d.getId()).orElseThrow().getName()).isEqualTo("Nome Atualizado");
    }

    @Test
    void editarSecretariaInexistente_retorna404() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(put("/departments/" + java.util.UUID.randomUUID()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpsertRequest("X", null, null, null))))
                .andExpect(status().isNotFound());
    }

    @Test
    void excluirSecretariaComoAdmin_removeDoRepositorio() throws Exception {
        Department d = saveDepartment("Para Excluir");
        String token = loginAs("admin");

        mockMvc.perform(authed(delete("/departments/" + d.getId()), token)).andExpect(status().isOk());
        assertThat(departments.findById(d.getId())).isEmpty();
    }

    @Test
    void qualquerUsuarioAutenticadoPodeListarSecretarias() throws Exception {
        saveDepartment("Visivel a Todos");
        for (String role : new String[] {"admin", "gerente", "recepcao", "professor", "aluno"}) {
            String token = loginAs(role);
            mockMvc.perform(authed(get("/departments"), token)).andExpect(status().isOk());
        }
    }

    @Test
    void recepcaoNaoPodeCriarSecretaria() throws Exception {
        String token = loginAs("recepcao");
        mockMvc.perform(authed(post("/departments"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpsertRequest("Indevida", null, null, null))))
                .andExpect(status().isForbidden());
    }

    @Test
    void professorNaoPodeEditarSecretaria() throws Exception {
        Department d = saveDepartment("Intocavel");
        String token = loginAs("professor");
        mockMvc.perform(authed(put("/departments/" + d.getId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new UpsertRequest("Alterada", null, null, null))))
                .andExpect(status().isForbidden());
    }

    @Test
    void alunoNaoPodeExcluirSecretaria() throws Exception {
        Department d = saveDepartment("Protegida");
        String token = loginAs("aluno");
        mockMvc.perform(authed(delete("/departments/" + d.getId()), token)).andExpect(status().isForbidden());
        assertThat(departments.findById(d.getId())).isPresent();
    }

    /**
     * Não há UNIQUE em {@code department.name} — nem no schema
     * ({@code V1__initial_schema.sql}) nem na entidade JPA. A SPEC (§8.8) só
     * declara unicidade explícita para CPF/sam_account_name/ldap_guid; para
     * secretaria não há tal exigência. Este teste documenta o comportamento
     * atual (permite nomes duplicados) — não é tratado como bug.
     */
    @Test
    void nomeDuplicadoEPermitidoAtualmente_semConstraintUnica() throws Exception {
        String token = loginAs("admin");
        String body = objectMapper.writeValueAsString(new UpsertRequest("Nome Repetido", null, null, null));

        mockMvc.perform(authed(post("/departments"), token).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk());
        mockMvc.perform(authed(post("/departments"), token).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk());

        assertThat(departments.findAll().stream().filter(d -> "Nome Repetido".equals(d.getName())).count())
                .isEqualTo(2);
    }

    private Department saveDepartment(String name) {
        Department d = new Department();
        d.setName(name);
        d.setActive(true);
        return departments.save(d);
    }
}
