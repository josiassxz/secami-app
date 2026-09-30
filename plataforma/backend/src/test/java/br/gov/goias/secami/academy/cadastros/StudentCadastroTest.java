package br.gov.goias.secami.academy.cadastros;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentDtos.UpsertRequest;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.Cpf;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Testes de integração de /students (cadastro de alunos). SPEC §9.3 (endpoints),
 * §11.1 (RBAC) e §14 (LGPD — CPF mascarado nas listagens).
 */
class StudentCadastroTest extends AbstractIntegrationTest {

    @Autowired StudentRepository students;

    // ---- criação: CPF válido / inválido / duplicado ----

    @Test
    void criarAlunoComCpfValido_retorna200ComCpfFormatado() throws Exception {
        String token = loginAs("admin");
        String cpf = CpfTestFactory.next();

        mockMvc.perform(authed(post("/students"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req("Fulano de Tal", cpf))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value("Fulano de Tal"))
                .andExpect(jsonPath("$.cpf").value(Cpf.format(cpf)))
                .andExpect(jsonPath("$.active").value(true));

        assertThat(students.findByCpf(cpf)).isPresent();
    }

    @Test
    void criarAlunoComCpfInvalido_retorna400() throws Exception {
        String token = loginAs("admin");
        // dígitos verificadores incorretos (não é um CPF real).
        mockMvc.perform(authed(post("/students"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req("CPF Invalido", "123.456.789-00"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors[?(@.field=='cpf')]").exists());

        assertThat(students.findByCpf("12345678900")).isEmpty();
    }

    @Test
    void criarAlunoComCpfDeDigitosRepetidos_retorna400() throws Exception {
        String token = loginAs("admin");
        // Passa no cálculo de módulo 11 mas não é CPF real (regra extra da validação).
        mockMvc.perform(authed(post("/students"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req("Repetido", "111.111.111-11"))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void criarAlunoSemNome_retorna400() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/students"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req("", CpfTestFactory.next()))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors[?(@.field=='fullName')]").exists());
    }

    @Test
    void criarAlunoComCpfJaCadastrado_retorna409() throws Exception {
        String token = loginAs("admin");
        String cpf = CpfTestFactory.next();
        saveStudent("Primeiro Titular", cpf);

        mockMvc.perform(authed(post("/students"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req("Segundo Titular", cpf))))
                .andExpect(status().isConflict());
    }

    // ---- busca por nome parcial e por CPF ----

    @Test
    void buscaPorNomeParcialFiltraCorretamente() throws Exception {
        saveStudent("Maria da Silva Santos", CpfTestFactory.next());
        saveStudent("João Pereira de Oliveira", CpfTestFactory.next());
        String token = loginAs("recepcao");

        JsonNode page = getJson(get("/students").param("q", "Silva Santos"), token);
        List<String> names = fullNamesOf(page);

        assertThat(names).contains("Maria da Silva Santos");
        assertThat(names).doesNotContain("João Pereira de Oliveira");
    }

    @Test
    void buscaPorCpfFiltraCorretamente() throws Exception {
        String cpfAlvo = CpfTestFactory.next();
        Student alvo = saveStudent("Alvo da Busca por CPF", cpfAlvo);
        saveStudent("Outro Aluno Qualquer", CpfTestFactory.next());
        String token = loginAs("admin");

        // Sufixo do CPF (onde a fábrica de testes varia os dígitos entre CPFs
        // sequenciais; dígitos só aparecem no campo cpf, nunca no nome).
        String trecho = cpfAlvo.substring(6);
        JsonNode page = getJson(get("/students").param("q", trecho), token);
        List<String> ids = idsOf(page);

        assertThat(ids).containsExactly(alvo.getId().toString());
    }

    // ---- paginação real ----

    @Test
    void listagemPaginadaRespeitaPageESize() throws Exception {
        for (int i = 1; i <= 25; i++) {
            saveStudent(String.format("Aluno Paginacao %02d", i), CpfTestFactory.next());
        }
        String token = loginAs("admin");

        JsonNode page0 = getJson(get("/students").param("page", "0").param("size", "10"), token);
        assertThat(page0.get("content")).hasSize(10);
        assertThat(page0.get("size").asInt()).isEqualTo(10);
        assertThat(page0.get("number").asInt()).isEqualTo(0);
        assertThat(page0.get("totalElements").asInt()).isEqualTo(25);
        assertThat(page0.get("totalPages").asInt()).isEqualTo(3);

        JsonNode page1 = getJson(get("/students").param("page", "1").param("size", "10"), token);
        assertThat(page1.get("number").asInt()).isEqualTo(1);
        assertThat(page1.get("content")).hasSize(10);

        JsonNode page2 = getJson(get("/students").param("page", "2").param("size", "10"), token);
        assertThat(page2.get("content")).hasSize(5);

        // As três páginas não podem se sobrepor.
        List<String> ids0 = idsOf(page0);
        List<String> ids1 = idsOf(page1);
        List<String> ids2 = idsOf(page2);
        assertThat(ids0).doesNotContainAnyElementsOf(ids1);
        assertThat(ids0).doesNotContainAnyElementsOf(ids2);
        assertThat(ids1).doesNotContainAnyElementsOf(ids2);
    }

    // ---- CPF mascarado na listagem (LGPD) ----

    @Test
    void listagemMascaraCpf_detalheMostraCompleto() throws Exception {
        String cpf = CpfTestFactory.next();
        Student s = saveStudent("Sigilo De Listagem", cpf);
        String token = loginAs("professor");

        JsonNode page = getJson(get("/students").param("q", "Sigilo De Listagem"), token);
        JsonNode found = firstById(page, s.getId());
        String cpfNaListagem = found.get("cpf").asText();

        assertThat(cpfNaListagem).isEqualTo(Cpf.mask(cpf));
        assertThat(cpfNaListagem).isNotEqualTo(Cpf.format(cpf));
        // O miolo do CPF (dígitos 4 a 9) não pode vazar na listagem.
        assertThat(cpfNaListagem).doesNotContain(cpf.substring(3, 9));

        // No detalhe (GET /students/{id}) o CPF vem completo (uso operacional, não listagem).
        mockMvc.perform(authed(get("/students/" + s.getId()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.cpf").value(Cpf.format(cpf)));
    }

    // ---- RBAC ----

    @Test
    void adminPodeCriarAluno() throws Exception {
        assertCreateStatus("admin", status().isOk());
    }

    @Test
    void gerentePodeCriarAluno() throws Exception {
        assertCreateStatus("gerente", status().isOk());
    }

    @Test
    void recepcaoNaoPodeCriarAluno() throws Exception {
        assertCreateStatus("recepcao", status().isForbidden());
    }

    @Test
    void professorNaoPodeCriarAluno() throws Exception {
        assertCreateStatus("professor", status().isForbidden());
    }

    @Test
    void alunoNaoPodeCriarAluno() throws Exception {
        assertCreateStatus("aluno", status().isForbidden());
    }

    @Test
    void recepcaoPodeListarAlunos() throws Exception {
        String token = loginAs("recepcao");
        mockMvc.perform(authed(get("/students"), token)).andExpect(status().isOk());
    }

    @Test
    void alunoNaoPodeListarAlunos() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/students"), token)).andExpect(status().isForbidden());
    }

    @Test
    void alunoNaoPodeEditarOutroAluno() throws Exception {
        Student alvo = saveStudent("Alvo de Edicao", CpfTestFactory.next());
        String token = loginAs("aluno");

        mockMvc.perform(authed(put("/students/" + alvo.getId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req("Alvo Editado Sem Permissao", null))))
                .andExpect(status().isForbidden());

        assertThat(students.findByIdAndDeletedAtIsNull(alvo.getId()).orElseThrow().getFullName())
                .isEqualTo("Alvo de Edicao");
    }

    @Test
    void adminPodeEditarAluno() throws Exception {
        Student alvo = saveStudent("Nome Antigo", CpfTestFactory.next());
        String token = loginAs("admin");

        mockMvc.perform(authed(put("/students/" + alvo.getId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req("Nome Novo", null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.fullName").value("Nome Novo"));
    }

    @Test
    void adminPodeExcluirAluno_softDelete() throws Exception {
        Student alvo = saveStudent("Para Excluir", CpfTestFactory.next());
        String token = loginAs("admin");

        mockMvc.perform(authed(delete("/students/" + alvo.getId()), token)).andExpect(status().isOk());

        // Soft delete: some da listagem/detalhe (deletedAt preenchido), não é removido fisicamente.
        mockMvc.perform(authed(get("/students/" + alvo.getId()), token)).andExpect(status().isNotFound());
        Student persisted = students.findById(alvo.getId()).orElseThrow();
        assertThat(persisted.getDeletedAt()).isNotNull();
        assertThat(persisted.isActive()).isFalse();
    }

    @Test
    void gerenteNaoPodeExcluirAluno() throws Exception {
        Student alvo = saveStudent("Protegido Contra Exclusao", CpfTestFactory.next());
        String token = loginAs("gerente");

        mockMvc.perform(authed(delete("/students/" + alvo.getId()), token)).andExpect(status().isForbidden());
        assertThat(students.findByIdAndDeletedAtIsNull(alvo.getId())).isPresent();
    }

    // ---- helpers ----

    private void assertCreateStatus(String role, org.springframework.test.web.servlet.ResultMatcher expected) throws Exception {
        String token = loginAs(role);
        mockMvc.perform(authed(post("/students"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req("Candidato " + role, CpfTestFactory.next()))))
                .andExpect(expected);
    }

    private static UpsertRequest req(String fullName, String cpf) {
        return new UpsertRequest(fullName, cpf, null, "Civil", null, null, null,
                null, null, null, null, null, null, null, null, null);
    }

    private Student saveStudent(String fullName, String cpf) {
        Student s = new Student();
        s.setFullName(fullName);
        s.setCpf(cpf);
        s.setStudentType("Civil");
        s.setActive(true);
        return students.save(s);
    }

    private JsonNode getJson(MockHttpServletRequestBuilder builder, String token) throws Exception {
        String json = mockMvc.perform(authed(builder, token))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(json);
    }

    private static List<String> fullNamesOf(JsonNode page) {
        List<String> names = new ArrayList<>();
        page.get("content").forEach(n -> names.add(n.get("fullName").asText()));
        return names;
    }

    private static List<String> idsOf(JsonNode page) {
        List<String> ids = new ArrayList<>();
        page.get("content").forEach(n -> ids.add(n.get("id").asText()));
        return ids;
    }

    private static JsonNode firstById(JsonNode page, UUID id) {
        for (JsonNode n : page.get("content")) {
            if (n.get("id").asText().equals(id.toString())) return n;
        }
        throw new AssertionError("Aluno " + id + " não encontrado na listagem retornada.");
    }
}
