package br.gov.goias.secami.training.exercise;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.training.exercise.ExerciseDtos.UpsertRequest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Catálogo de exercícios (SPEC §8.4 / §11.2): CRUD, busca por grupo muscular,
 * RBAC de escrita (admin/professor) e unicidade de {@code slug}.
 */
class ExerciseIntegrationTest extends AbstractIntegrationTest {

    @Autowired private ExerciseRepository exerciseRepository;

    // ---- criação: RBAC ----

    @Test
    void professorCriaExercicioComSucesso() throws Exception {
        String token = loginAs("professor");
        mockMvc.perform(authed(post("/exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("Supino Reto", "peito"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.name").value("Supino Reto"))
                .andExpect(jsonPath("$.muscleGroup").value("peito"))
                .andExpect(jsonPath("$.arquivado").value(false));
    }

    @Test
    void adminCriaExercicioComSucesso() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("Levantamento Terra", "posterior"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Levantamento Terra"));
    }

    @Test
    void alunoNaoPodeCriarExercicio() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(post("/exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("Rosca Direta", "biceps"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void recepcaoNaoPodeCriarExercicio() throws Exception {
        String token = loginAs("recepcao");
        mockMvc.perform(authed(post("/exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("Rosca Direta", "biceps"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void gerenteNaoPodeCriarExercicio() throws Exception {
        String token = loginAs("gerente");
        mockMvc.perform(authed(post("/exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("Rosca Direta", "biceps"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void criarExercicioSemAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(post("/exercises")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("Rosca Direta", "biceps"))))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void criarExercicioSemNomeRetorna400() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("", "peito"))))
                .andExpect(status().isBadRequest());
    }

    // ---- listagem / busca ----

    @Test
    void listarSemAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(get("/exercises")).andExpect(status().isUnauthorized());
    }

    @Test
    void buscaPorGrupoMuscularFiltraCorretamente() throws Exception {
        String adminToken = loginAs("admin");
        criarExercicio(adminToken, "Supino Reto - Filtro", "peito-filtro-teste");
        criarExercicio(adminToken, "Remada Curvada - Filtro", "costas-filtro-teste");

        // Busca filtrando por um grupo específico não deve trazer o do outro grupo.
        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(get("/exercises").param("grupo", "peito-filtro-teste"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].name").value("Supino Reto - Filtro"))
                .andExpect(jsonPath("$[0].muscleGroup").value("peito-filtro-teste"));

        mockMvc.perform(authed(get("/exercises").param("grupo", "costas-filtro-teste"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].name").value("Remada Curvada - Filtro"));

        // Sem filtro, ambos aparecem.
        mockMvc.perform(authed(get("/exercises"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.name=='Supino Reto - Filtro')]").exists())
                .andExpect(jsonPath("$[?(@.name=='Remada Curvada - Filtro')]").exists());
    }

    @Test
    void buscaPorGrupoInexistenteNaoRetornaNada() throws Exception {
        String adminToken = loginAs("admin");
        criarExercicio(adminToken, "Supino Inclinado - Filtro2", "peito-filtro-teste-2");

        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(get("/exercises").param("grupo", "grupo-que-nao-existe-xyz"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    // ---- edição ----

    @Test
    void atualizarExercicioAlteraCampos() throws Exception {
        String token = loginAs("professor");
        UUID id = criarExercicio(token, "Agachamento Livre", "pernas");

        UpsertRequest update = new UpsertRequest(
                "Agachamento Livre (atualizado)", "pernas-posterior", "nova descrição",
                "barra e anilhas", "agachar", "http://video/exemplo", null, null);

        mockMvc.perform(authed(put("/exercises/{id}", id), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(update)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(id.toString()))
                .andExpect(jsonPath("$.name").value("Agachamento Livre (atualizado)"))
                .andExpect(jsonPath("$.muscleGroup").value("pernas-posterior"))
                .andExpect(jsonPath("$.description").value("nova descrição"));
    }

    @Test
    void alunoNaoPodeAtualizarExercicio() throws Exception {
        String professorToken = loginAs("professor");
        UUID id = criarExercicio(professorToken, "Leg Press", "pernas-2");

        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(put("/exercises/{id}", id), alunoToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("Leg Press hackeado", "pernas-2"))))
                .andExpect(status().isForbidden());
    }

    @Test
    void atualizarExercicioInexistenteRetorna404() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(put("/exercises/{id}", UUID.randomUUID()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert("Não existe", "x"))))
                .andExpect(status().isNotFound());
    }

    // ---- exclusão (arquivamento) ----

    @Test
    void excluirExercicioArquivaEmVezDeApagarERemoveDaBusca() throws Exception {
        String token = loginAs("admin");
        UUID id = criarExercicio(token, "Cadeira Extensora", "pernas-arquivamento-teste");

        mockMvc.perform(authed(delete("/exercises/{id}", id), token))
                .andExpect(status().isOk());

        // Continua existindo no banco (histórico preservado), mas arquivado.
        Exercise persisted = exerciseRepository.findById(id).orElseThrow();
        assertThat(persisted.isArquivado()).isTrue();

        // Some da busca padrão (que filtra arquivado = false).
        mockMvc.perform(authed(get("/exercises").param("grupo", "pernas-arquivamento-teste"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void alunoNaoPodeExcluirExercicio() throws Exception {
        String professorToken = loginAs("professor");
        UUID id = criarExercicio(professorToken, "Panturrilha", "pernas-3");

        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(delete("/exercises/{id}", id), alunoToken))
                .andExpect(status().isForbidden());
    }

    // ---- slug único (constraint de banco, V3__exercise_slug_and_sync.sql) ----

    @Test
    void slugDeveSerUnicoNoBanco() throws Exception {
        String slug = "supino-reto-unico-" + UUID.randomUUID();

        Exercise primeiro = new Exercise();
        primeiro.setName("Supino Reto");
        primeiro.setSlug(slug);
        exerciseRepository.saveAndFlush(primeiro);

        Exercise duplicado = new Exercise();
        duplicado.setName("Supino Reto (outro registro)");
        duplicado.setSlug(slug);

        assertThrows(DataIntegrityViolationException.class,
                () -> exerciseRepository.saveAndFlush(duplicado));
    }

    // ---- helpers ----

    private UUID criarExercicio(String token, String nome, String grupo) throws Exception {
        String response = mockMvc.perform(authed(post("/exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(upsert(nome, grupo))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return UUID.fromString(objectMapper.readTree(response).get("id").asText());
    }

    private UpsertRequest upsert(String name, String muscleGroup) {
        return new UpsertRequest(name, muscleGroup, "descrição de teste", "equipamento", "padrão", null, null, null);
    }

    private String toJson(Object o) throws Exception {
        return objectMapper.writeValueAsString(o);
    }
}
