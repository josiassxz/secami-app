package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.punicao.PunicaoRepository;
import br.gov.goias.secami.academy.punicao.PunicaoService;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.identity.Roles;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Punições (Lutas): catálogo, aplicar só a aluno de Lutas, cumprir e o ciclo —
 * a cada 2 cumpridas (padrão) as mais antigas são encerradas e saem da lista.
 */
class PunicaoFluxoTest extends SchedulingTestSupport {

    @Autowired PunicaoRepository punicoes;
    @Autowired PunicaoService service;

    private String instrutorLutas() throws Exception {
        String sam = "lutas." + UUID.randomUUID().toString().substring(0, 6);
        UUID id = newAlunoUser(sam);
        var u = appUserRepository.findById(id).orElseThrow();
        u.getRoles().clear();
        u.getRoles().add(Roles.PROFESSOR);
        u.getRoles().add(Roles.LUTAS);
        appUserRepository.save(u);
        return loginAs(sam);
    }

    private Student alunoLutas() {
        Student s = newStudent(Student.TIPO_LUTAS);
        s.setTurmaLutas(Student.TURMA_FEMININO);
        s.setStatusCadastro(Student.STATUS_APROVADO);
        return studentRepository.save(s);
    }

    private ResultActions postJson(String token, String url, Object body) throws Exception {
        return mockMvc.perform(authed(post(url), token)
                .contentType(MediaType.APPLICATION_JSON).content(objectMapper.writeValueAsString(body)));
    }

    private String item(String token, String nome) throws Exception {
        return readJson(postJson(token, "/punicoes/itens", Map.of("nome", nome)).andExpect(status().isOk()))
                .get("id").asText();
    }

    private String aplicar(String token, Student s, String... itens) throws Exception {
        return readJson(postJson(token, "/punicoes/aplicar", Map.of("studentId", s.getId(), "itemIds", List.of(itens)))
                .andExpect(status().isOk())).get("id").asText();
    }

    @Test
    void cicloDeDuasCumpridasEncerraEPendenteContinua() throws Exception {
        String token = instrutorLutas();
        String flexoes = item(token, "10 flexões");
        String coca = item(token, "1 Coca-Cola");
        Student s = alunoLutas();

        String p1 = aplicar(token, s, flexoes, coca);
        JsonNode aberta = readJson(mockMvc.perform(authed(get("/punicoes/alunos/" + s.getId()), token)));
        assertThat(aberta.get(0).get("itens").size()).isEqualTo(2);
        assertThat(aberta.get(0).get("status").asText()).isEqualTo("PENDENTE");

        String p2 = aplicar(token, s, flexoes);
        String p3 = aplicar(token, s, coca);
        mockMvc.perform(authed(post("/punicoes/" + p1 + "/cumprir"), token)).andExpect(status().isOk());
        JsonNode depois = readJson(mockMvc.perform(authed(post("/punicoes/" + p3 + "/cumprir"), token))
                .andExpect(status().isOk()));

        // p1 e p3 fecharam o ciclo de 2 e saíram; p2 (pendente) continua.
        assertThat(depois.size()).isEqualTo(1);
        assertThat(depois.get(0).get("id").asText()).isEqualTo(p2);
        assertThat(punicoes.findById(UUID.fromString(p1)).orElseThrow().getStatus()).isEqualTo("CONCLUIDA");
        JsonNode historico = readJson(mockMvc.perform(authed(get("/punicoes/alunos/" + s.getId() + "/historico"), token)));
        assertThat(historico.size()).isEqualTo(3);
    }

    @Test
    void soAlunoDeLutasRecebePunicao() throws Exception {
        String token = instrutorLutas();
        String flexoes = item(token, "10 flexões");
        Student civil = newStudent(Student.TIPO_CIVIL);
        postJson(token, "/punicoes/aplicar", Map.of("studentId", civil.getId(), "itemIds", List.of(flexoes)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("Lutas")));
    }

    @Test
    void soExcluiPendente() throws Exception {
        String token = instrutorLutas();
        String flexoes = item(token, "10 flexões");
        Student s = alunoLutas();
        String p1 = aplicar(token, s, flexoes);
        mockMvc.perform(authed(post("/punicoes/" + p1 + "/cumprir"), token)).andExpect(status().isOk());
        mockMvc.perform(authed(delete("/punicoes/" + p1), token)).andExpect(status().isUnprocessableEntity());
        String p2 = aplicar(token, s, flexoes);
        mockMvc.perform(authed(delete("/punicoes/" + p2), token)).andExpect(status().isNoContent());
    }

    @Test
    void instrutorSemPapelDeLutasNaoAcessa() throws Exception {
        mockMvc.perform(authed(get("/punicoes/alunos"), loginAs("professor"))).andExpect(status().isForbidden());
    }

    @Test
    void alunoDeLutasVeAsDeleEmAberto() throws Exception {
        String token = instrutorLutas();
        String flexoes = item(token, "10 flexões");
        Student s = alunoLutas();
        UUID userId = newAlunoUser("aluno.lutas." + UUID.randomUUID().toString().substring(0, 6));
        vinculadoAoUsuario(s, userId);
        aplicar(token, s, flexoes);
        String sam = appUserRepository.findById(userId).orElseThrow().getSamAccountName();

        JsonNode minhas = readJson(mockMvc.perform(authed(get("/me/punicoes"), loginAs(sam))).andExpect(status().isOk()));
        assertThat(minhas.size()).isEqualTo(1);
        assertThat(minhas.get(0).get("itens").get(0).get("nome").asText()).isEqualTo("10 flexões");
    }

    @Test
    void marcarInstrutorDeLutasNaEdicaoDaOPapelLutas() throws Exception {
        UUID userId = newAlunoUser("prof.lutas." + UUID.randomUUID().toString().substring(0, 6));
        Student s = vinculadoAoUsuario(newStudent(Student.TIPO_INSTRUTOR), userId);
        String body = objectMapper.writeValueAsString(Map.of("fullName", s.getFullName(), "cpf", s.getCpf(),
                "studentType", "Instrutor", "instrutorLutas", true));
        mockMvc.perform(authed(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/students/" + s.getId()),
                        loginAs("admin")).contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isOk()).andExpect(jsonPath("$.instrutorLutas").value(true));
        assertThat(appUserRepository.findById(userId).orElseThrow().getRoles()).contains(Roles.LUTAS, Roles.PROFESSOR);

        String sem = objectMapper.writeValueAsString(Map.of("fullName", s.getFullName(), "cpf", s.getCpf(),
                "studentType", "Instrutor", "instrutorLutas", false));
        mockMvc.perform(authed(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/students/" + s.getId()),
                loginAs("admin")).contentType(MediaType.APPLICATION_JSON).content(sem)).andExpect(status().isOk());
        assertThat(appUserRepository.findById(userId).orElseThrow().getRoles()).doesNotContain(Roles.LUTAS);
    }

    @Test
    void cumpridaSozinhaEncerraDepoisDoPrazo() throws Exception {
        String token = instrutorLutas();
        String flexoes = item(token, "10 flexões");
        Student s = alunoLutas();
        String p1 = aplicar(token, s, flexoes);
        mockMvc.perform(authed(post("/punicoes/" + p1 + "/cumprir"), token)).andExpect(status().isOk());
        var p = punicoes.findById(UUID.fromString(p1)).orElseThrow();
        p.setCumpridaEm(OffsetDateTime.now().minusDays(31));
        punicoes.save(p);

        assertThat(service.encerrarCumpridasAntigas()).isGreaterThanOrEqualTo(1);
        assertThat(punicoes.findById(UUID.fromString(p1)).orElseThrow().getStatus()).isEqualTo("CONCLUIDA");
    }
}
