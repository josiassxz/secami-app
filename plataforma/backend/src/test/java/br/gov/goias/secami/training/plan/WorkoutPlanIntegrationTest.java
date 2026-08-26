package br.gov.goias.secami.training.plan;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.training.TrainingTestSupport;
import br.gov.goias.secami.training.exercise.ExerciseDtos;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Fichas de treino (SPEC §8.4 / §9.3 / §11.2): prescrição pelo professor,
 * leitura restrita ao próprio aluno via {@code /me/workout-plans}, RBAC de
 * escrita e edição/desativação.
 */
class WorkoutPlanIntegrationTest extends TrainingTestSupport {

    @Autowired private WorkoutPlanRepository workoutPlanRepository;

    @Test
    void professorCriaFichaComMultiplosExercicios() throws Exception {
        String professorToken = loginAs("professor");
        Student aluno = createStudentFor("aluno");
        UUID ex1 = criarExercicio(professorToken, "Supino Reto", "peito-plan-teste");
        UUID ex2 = criarExercicio(professorToken, "Puxada Alta", "costas-plan-teste");

        String body = """
                {
                  "studentId": "%s",
                  "sheetLabel": "A",
                  "title": "Ficha A - Iniciante",
                  "exercises": [
                    {"exerciseId": "%s", "sets": 4, "reps": "10-12", "restSeconds": 60, "notes": "carga leve"},
                    {"exerciseId": "%s", "sets": 3, "reps": "12-15", "restSeconds": 45},
                    {"exerciseName": "Prancha Isométrica", "sets": 3, "reps": "60s", "restSeconds": 30}
                  ]
                }
                """.formatted(aluno.getId(), ex1, ex2);

        String response = mockMvc.perform(authed(post("/workout-plans"), professorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.studentId").value(aluno.getId().toString()))
                .andExpect(jsonPath("$.sheetLabel").value("A"))
                .andExpect(jsonPath("$.title").value("Ficha A - Iniciante"))
                .andExpect(jsonPath("$.active").value(true))
                .andExpect(jsonPath("$.exercises.length()").value(3))
                .andExpect(jsonPath("$.exercises[0].exerciseName").value("Supino Reto"))
                .andExpect(jsonPath("$.exercises[0].ordem").value(0))
                .andExpect(jsonPath("$.exercises[1].exerciseName").value("Puxada Alta"))
                .andExpect(jsonPath("$.exercises[1].ordem").value(1))
                .andExpect(jsonPath("$.exercises[2].exerciseName").value("Prancha Isométrica"))
                .andExpect(jsonPath("$.exercises[2].ordem").value(2))
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(response);
        assertThat(json.get("professorId").asText()).isEqualTo(devUser("professor").getId().toString());
    }

    @Test
    void alunoVePropriaFichaViaMe() throws Exception {
        String professorToken = loginAs("professor");
        Student aluno = createStudentFor("aluno");
        criarFicha(professorToken, aluno.getId(), "A", "Ficha do próprio aluno");

        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(get("/me/workout-plans"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].title").value("Ficha do próprio aluno"))
                .andExpect(jsonPath("$[0].studentId").value(aluno.getId().toString()));
    }

    @Test
    void alunoNaoVeFichaDeOutroAluno() throws Exception {
        String professorToken = loginAs("professor");
        Student aluno = createStudentFor("aluno");
        Student outro = createStandaloneStudent("Fichas-Isolamento");
        criarFicha(professorToken, aluno.getId(), "A", "Ficha do aluno logado");
        criarFicha(professorToken, outro.getId(), "A", "Ficha de outro aluno - não deve aparecer");

        String alunoToken = loginAs("aluno");
        String response = mockMvc.perform(authed(get("/me/workout-plans"), alunoToken))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();

        JsonNode json = objectMapper.readTree(response);
        assertThat(json).hasSize(1);
        assertThat(json.get(0).get("title").asText()).isEqualTo("Ficha do aluno logado");
        assertThat(json.get(0).get("studentId").asText()).isEqualTo(aluno.getId().toString());
    }

    @Test
    void alunoSemPerfilVinculadoRecebe404AoConsultarMe() throws Exception {
        // "aluno" dev sem Student vinculado nesta transação (não chamamos createStudentFor).
        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(get("/me/workout-plans"), alunoToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void alunoNaoPodeCriarFichaParaSiMesmo() throws Exception {
        Student aluno = createStudentFor("aluno");
        String alunoToken = loginAs("aluno");

        String body = """
                {"studentId": "%s", "sheetLabel": "A", "title": "Ficha auto-prescrita", "exercises": []}
                """.formatted(aluno.getId());

        mockMvc.perform(authed(post("/workout-plans"), alunoToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden());
    }

    @Test
    void recepcaoNaoPodeCriarFicha() throws Exception {
        Student aluno = createStudentFor("aluno");
        String recepcaoToken = loginAs("recepcao");

        String body = """
                {"studentId": "%s", "sheetLabel": "A", "title": "Ficha via recepção", "exercises": []}
                """.formatted(aluno.getId());

        mockMvc.perform(authed(post("/workout-plans"), recepcaoToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden());
    }

    @Test
    void criarFichaParaAlunoInexistenteRetorna404() throws Exception {
        String professorToken = loginAs("professor");
        String body = """
                {"studentId": "%s", "sheetLabel": "A", "title": "Ficha órfã", "exercises": []}
                """.formatted(UUID.randomUUID());

        mockMvc.perform(authed(post("/workout-plans"), professorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isNotFound());
    }

    @Test
    void professorAtualizaFichaSubstituiExercicios() throws Exception {
        String professorToken = loginAs("professor");
        Student aluno = createStudentFor("aluno");
        UUID planId = criarFicha(professorToken, aluno.getId(), "A", "Ficha original");

        String update = """
                {
                  "studentId": "%s",
                  "sheetLabel": "B",
                  "title": "Ficha revisada",
                  "active": true,
                  "exercises": [
                    {"exerciseName": "Remada Baixa", "sets": 3, "reps": "10", "restSeconds": 60}
                  ]
                }
                """.formatted(aluno.getId());

        mockMvc.perform(authed(put("/workout-plans/{id}", planId), professorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(update))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sheetLabel").value("B"))
                .andExpect(jsonPath("$.title").value("Ficha revisada"))
                .andExpect(jsonPath("$.exercises.length()").value(1))
                .andExpect(jsonPath("$.exercises[0].exerciseName").value("Remada Baixa"));
    }

    @Test
    void professorDesativaFichaViaUpdatePermaneceListadaComoInativa() throws Exception {
        String professorToken = loginAs("professor");
        Student aluno = createStudentFor("aluno");
        UUID planId = criarFicha(professorToken, aluno.getId(), "A", "Ficha a desativar");

        String update = """
                {"studentId": "%s", "sheetLabel": "A", "title": "Ficha a desativar", "active": false, "exercises": []}
                """.formatted(aluno.getId());

        mockMvc.perform(authed(put("/workout-plans/{id}", planId), professorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(update))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active").value(false));

        mockMvc.perform(authed(get("/students/{id}/workout-plans", aluno.getId()), professorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].active").value(false));
    }

    @Test
    void professorExcluiFichaRemoveDaListagemMasPreservaHistorico() throws Exception {
        String professorToken = loginAs("professor");
        Student aluno = createStudentFor("aluno");
        UUID planId = criarFicha(professorToken, aluno.getId(), "A", "Ficha a excluir");

        mockMvc.perform(authed(delete("/workout-plans/{id}", planId), professorToken))
                .andExpect(status().isOk());

        mockMvc.perform(authed(get("/students/{id}/workout-plans", aluno.getId()), professorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        WorkoutPlan persisted = workoutPlanRepository.findById(planId).orElseThrow();
        assertThat(persisted.getDeletedAt()).isNotNull();
        assertThat(persisted.isActive()).isFalse();
    }

    @Test
    void alunoNaoPodeListarFichasPorStudentId() throws Exception {
        Student aluno = createStudentFor("aluno");
        String alunoToken = loginAs("aluno");

        mockMvc.perform(authed(get("/students/{id}/workout-plans", aluno.getId()), alunoToken))
                .andExpect(status().isForbidden());
    }

    // ---- helpers ----

    private UUID criarExercicio(String token, String nome, String grupo) throws Exception {
        var req = new ExerciseDtos.UpsertRequest(nome, grupo, null, null, null, null, null, null);
        String response = mockMvc.perform(authed(post("/exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return UUID.fromString(objectMapper.readTree(response).get("id").asText());
    }

    private UUID criarFicha(String professorToken, UUID studentId, String sheetLabel, String title) throws Exception {
        String body = """
                {"studentId": "%s", "sheetLabel": "%s", "title": "%s", "exercises": []}
                """.formatted(studentId, sheetLabel, title);
        String response = mockMvc.perform(authed(post("/workout-plans"), professorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return UUID.fromString(objectMapper.readTree(response).get("id").asText());
    }
}
