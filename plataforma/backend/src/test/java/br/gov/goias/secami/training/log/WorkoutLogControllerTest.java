package br.gov.goias.secami.training.log;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.training.TrainingTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Execução diária da ficha pelo aluno — {@code /me/workout-logs} (SPEC §8.4 /
 * §9.3): grava/lê SEMPRE o log do dono do JWT (não existe id de aluno no
 * payload), então isolamento entre contas é garantido pela própria resolução
 * de {@code Student} a partir do usuário autenticado.
 */
class WorkoutLogControllerTest extends TrainingTestSupport {

    @Test
    void alunoGravaEDepoisLeSeuProprioLogDoDia() throws Exception {
        createStudentFor("aluno");
        String token = loginAs("aluno");
        LocalDate hoje = LocalDate.now();

        String body = objectMapper.writeValueAsString(Map.of(
                "date", hoje.toString(),
                "exercises", List.of(
                        Map.of("exerciseName", "Supino Reto", "load", "40kg"),
                        Map.of("exerciseName", "Agachamento", "load", "60kg"))));

        mockMvc.perform(authed(put("/me/workout-logs"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.date").value(hoje.toString()))
                .andExpect(jsonPath("$.completed").value(true))
                .andExpect(jsonPath("$.exercises.length()").value(2));

        mockMvc.perform(authed(get("/me/workout-logs/today"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.date").value(hoje.toString()))
                .andExpect(jsonPath("$.exercises[0].exerciseName").value("Supino Reto"));
    }

    @Test
    void upsertSemExerciciosNaoFicaCompleto() throws Exception {
        createStudentFor("aluno");
        String token = loginAs("aluno");
        LocalDate hoje = LocalDate.now();

        String body = objectMapper.writeValueAsString(Map.of(
                "date", hoje.toString(),
                "exercises", List.of()));

        mockMvc.perform(authed(put("/me/workout-logs"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.completed").value(false));
    }

    @Test
    void upsertNoMesmoDiaAtualizaOMesmoLogEmVezDeCriarOutro() throws Exception {
        createStudentFor("aluno");
        String token = loginAs("aluno");
        LocalDate hoje = LocalDate.now();

        String primeiro = objectMapper.writeValueAsString(Map.of(
                "date", hoje.toString(),
                "exercises", List.of(Map.of("exerciseName", "Supino Reto", "load", "40kg"))));
        mockMvc.perform(authed(put("/me/workout-logs"), token)
                        .contentType(MediaType.APPLICATION_JSON).content(primeiro))
                .andExpect(status().isOk());

        String segundo = objectMapper.writeValueAsString(Map.of(
                "date", hoje.toString(),
                "exercises", List.of(Map.of("exerciseName", "Supino Reto", "load", "45kg"),
                        Map.of("exerciseName", "Puxada", "load", "50kg"))));
        mockMvc.perform(authed(put("/me/workout-logs"), token)
                        .contentType(MediaType.APPLICATION_JSON).content(segundo))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exercises.length()").value(2));

        mockMvc.perform(authed(get("/me/workout-logs"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1)); // 1 log por (aluno, data), não 2
    }

    @Test
    void alunoNaoVeLogDeOutroAlunoNoHistoricoNemNoDia() throws Exception {
        createStudentFor("aluno");
        Student outro = createStudentFor("professor", "Outro Aluno (usando login professor)");

        String tokenAluno = loginAs("aluno");
        String tokenOutro = loginAs("professor");
        LocalDate hoje = LocalDate.now();

        // "Outro" grava o log dele.
        String bodyOutro = objectMapper.writeValueAsString(Map.of(
                "date", hoje.toString(),
                "exercises", List.of(Map.of("exerciseName", "Treino Sigiloso do Outro", "load", "99kg"))));
        mockMvc.perform(authed(put("/me/workout-logs"), tokenOutro)
                        .contentType(MediaType.APPLICATION_JSON).content(bodyOutro))
                .andExpect(status().isOk());

        // Aluno grava o dele próprio.
        String bodyAluno = objectMapper.writeValueAsString(Map.of(
                "date", hoje.toString(),
                "exercises", List.of(Map.of("exerciseName", "Meu Treino", "load", "10kg"))));
        mockMvc.perform(authed(put("/me/workout-logs"), tokenAluno)
                        .contentType(MediaType.APPLICATION_JSON).content(bodyAluno))
                .andExpect(status().isOk());

        // O "today" do aluno mostra só o dele.
        mockMvc.perform(authed(get("/me/workout-logs/today"), tokenAluno))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exercises[0].exerciseName").value("Meu Treino"));

        // O histórico do aluno não contém o log do outro (nem por id, nem por conteúdo).
        mockMvc.perform(authed(get("/me/workout-logs"), tokenAluno))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[?(@.exercises[0].exerciseName=='Treino Sigiloso do Outro')]").doesNotExist());

        assertThat(outro).isNotNull(); // sanity: aluno "outro" foi de fato criado
    }

    @Test
    void semStudentVinculadoRetorna404() throws Exception {
        // "recepcao" é um app_user dev válido, mas sem Student associado.
        String token = loginAs("recepcao");
        mockMvc.perform(authed(get("/me/workout-logs/today"), token))
                .andExpect(status().isNotFound());
    }

    @Test
    void semAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(get("/me/workout-logs/today")).andExpect(status().isUnauthorized());
        mockMvc.perform(get("/me/workout-logs")).andExpect(status().isUnauthorized());
    }
}
