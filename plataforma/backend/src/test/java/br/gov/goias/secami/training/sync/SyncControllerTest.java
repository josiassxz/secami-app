package br.gov.goias.secami.training.sync;

import br.gov.goias.secami.training.TrainingTestSupport;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Sync offline-first do app (SPEC §10.3 / E9) — {@code /sync/{table}} push
 * (upsert com checagem de ownership) e pull (incremental por {@code since}).
 * Ver {@link SyncService}: dono sempre resolvido do JWT, nunca do payload.
 */
class SyncControllerTest extends TrainingTestSupport {

    @Autowired private JdbcTemplate jdbc;

    // ---- push: ownership ----

    @Test
    void pushRoutineNovaPersisteVinculadaAoUsuarioAutenticado() throws Exception {
        String token = loginAs("aluno");
        UUID alunoId = devUser("aluno").getId();
        UUID routineId = UUID.randomUUID();

        mockMvc.perform(authed(post("/sync/routines"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(routinePayload(routineId, alunoId, "Rotina A", now())))))
                .andExpect(status().isOk());

        Map<String, Object> row = jdbc.queryForMap("select * from routine where id = ?", routineId);
        assertThat(row.get("user_id")).isEqualTo(alunoId);
        assertThat(row.get("nome")).isEqualTo("Rotina A");
    }

    @Test
    void pushRoutineComUserIdDeOutroUsuarioEhRejeitadaENaoGrava() throws Exception {
        String token = loginAs("aluno");
        UUID professorId = devUser("professor").getId();
        UUID routineId = UUID.randomUUID();

        mockMvc.perform(authed(post("/sync/routines"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(routinePayload(routineId, professorId, "Rotina Alheia", now())))))
                .andExpect(status().isUnprocessableEntity());

        List<Map<String, Object>> rows = jdbc.queryForList("select 1 from routine where id = ?", routineId);
        assertThat(rows).isEmpty();
    }

    /**
     * IMPORTANTE: roda com {@code Propagation.NOT_SUPPORTED} pra suspender a
     * transação de teste (rollback automático) de {@link br.gov.goias.secami.AbstractIntegrationTest}.
     * Se ficasse aninhado nela, {@code pushRoutines} (REQUIRED) apenas ENTRARIA
     * na transação de teste já aberta — a exceção marcaria "rollback-only",
     * mas o ROLLBACK físico só aconteceria no fim do método de teste, então a
     * consulta abaixo (mesma conexão/transação) enxergaria a linha "válida"
     * como presente mesmo sem bug nenhum (write própria, ainda não commitada,
     * sempre visível pra quem a escreveu). Suspender a transação de teste faz
     * {@code pushRoutines} ser de fato a fronteira transacional mais externa
     * — exatamente como em produção (controller não abre transação própria,
     * {@code open-in-view=false}) — e a asserção abaixo reflete o estado real
     * pós-commit/rollback. Por rodar sem rollback automático, limpa manualmente
     * no {@code finally}.
     */
    @Test
    @org.springframework.transaction.annotation.Transactional(
            propagation = org.springframework.transaction.annotation.Propagation.NOT_SUPPORTED)
    void pushComLinhaValidaEInvalidaNoMesmoLoteNaoGravaNadaTransacaoAtomica() throws Exception {
        String token = loginAs("aluno");
        UUID alunoId = devUser("aluno").getId();
        UUID outroId = devUser("professor").getId();
        UUID valida = UUID.randomUUID();
        UUID invalida = UUID.randomUUID();

        try {
            mockMvc.perform(authed(post("/sync/routines"), token)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(toJson(List.of(
                                    routinePayload(valida, alunoId, "Valida", now()),
                                    routinePayload(invalida, outroId, "Invalida", now())))))
                    .andExpect(status().isUnprocessableEntity());

            // Linha válida também não persiste: o lote inteiro faz rollback.
            List<Map<String, Object>> rows = jdbc.queryForList("select 1 from routine where id = ?", valida);
            assertThat(rows).isEmpty();
        } finally {
            jdbc.update("delete from routine where id in (?, ?)", valida, invalida);
        }
    }

    @Test
    void pushRoutineExerciseDeRotinaQueNaoPertenceAoUsuarioEhRejeitada() throws Exception {
        String alunoToken = loginAs("aluno");
        String professorToken = loginAs("professor");
        UUID professorId = devUser("professor").getId();

        // Rotina de outro usuário (professor), criada legitimamente por ele.
        UUID rotinaDoProfessor = UUID.randomUUID();
        mockMvc.perform(authed(post("/sync/routines"), professorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(routinePayload(rotinaDoProfessor, professorId, "Rotina Prof", now())))))
                .andExpect(status().isOk());

        // Aluno tenta pendurar um exercício na rotina do professor.
        Map<String, Object> exercicio = new LinkedHashMap<>();
        exercicio.put("id", UUID.randomUUID().toString());
        exercicio.put("routine_id", rotinaDoProfessor.toString());
        exercicio.put("exercise_id", "seed:supino-reto");
        exercicio.put("ordem", 1);
        exercicio.put("series_planejadas", List.of());
        exercicio.put("notas", null);
        exercicio.put("grupo_id", null);
        exercicio.put("grupo_tipo", "normal");
        exercicio.put("rounds", null);
        exercicio.put("criado_em", now());
        exercicio.put("updated_at", now());
        exercicio.put("deleted_at", null);
        exercicio.put("device_id", "device-teste");

        mockMvc.perform(authed(post("/sync/routine_exercises"), alunoToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(exercicio))))
                .andExpect(status().isUnprocessableEntity());

        List<Map<String, Object>> rows = jdbc.queryForList(
                "select 1 from routine_exercise where routine_id = ?", rotinaDoProfessor);
        assertThat(rows).isEmpty();
    }

    @Test
    void pushRoutineExerciseDeRotinaPropriaEhAceita() throws Exception {
        String token = loginAs("aluno");
        UUID alunoId = devUser("aluno").getId();
        UUID rotina = UUID.randomUUID();
        mockMvc.perform(authed(post("/sync/routines"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(routinePayload(rotina, alunoId, "Minha Rotina", now())))))
                .andExpect(status().isOk());

        Map<String, Object> exercicio = new LinkedHashMap<>();
        exercicio.put("id", UUID.randomUUID().toString());
        exercicio.put("routine_id", rotina.toString());
        exercicio.put("exercise_id", "seed:supino-reto");
        exercicio.put("ordem", 1);
        exercicio.put("series_planejadas", List.of());
        exercicio.put("grupo_tipo", "normal");
        exercicio.put("updated_at", now());
        exercicio.put("device_id", "device-teste");

        mockMvc.perform(authed(post("/sync/routine_exercises"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(exercicio))))
                .andExpect(status().isOk());

        List<Map<String, Object>> rows = jdbc.queryForList(
                "select 1 from routine_exercise where routine_id = ?", rotina);
        assertThat(rows).hasSize(1);
    }

    // ---- pull: filtro incremental ----

    @Test
    void pullRoutinesFiltraPorSinceRetornandoSoAsMaisNovas() throws Exception {
        String token = loginAs("aluno");
        UUID alunoId = devUser("aluno").getId();

        OffsetDateTime antiga = OffsetDateTime.now(ZoneOffset.UTC).minusHours(4);
        OffsetDateTime meio = OffsetDateTime.now(ZoneOffset.UTC).minusHours(2);
        OffsetDateTime nova = OffsetDateTime.now(ZoneOffset.UTC);

        UUID idAntiga = UUID.randomUUID();
        UUID idNova = UUID.randomUUID();

        mockMvc.perform(authed(post("/sync/routines"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(routinePayload(idAntiga, alunoId, "Antiga", antiga)))))
                .andExpect(status().isOk());
        mockMvc.perform(authed(post("/sync/routines"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(routinePayload(idNova, alunoId, "Nova", nova)))))
                .andExpect(status().isOk());

        // since = ponto intermediário: só a rotina "nova" (updated_at > since) deve voltar.
        mockMvc.perform(authed(get("/sync/routines").param("since", meio.toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].nome").value("Nova"));

        // Sem "since", o pull inicial traz as duas.
        mockMvc.perform(authed(get("/sync/routines"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.nome=='Antiga')]").exists())
                .andExpect(jsonPath("$[?(@.nome=='Nova')]").exists());
    }

    @Test
    void pullRoutinesNaoRetornaRotinaDeOutroUsuario() throws Exception {
        String professorToken = loginAs("professor");
        UUID professorId = devUser("professor").getId();
        UUID rotina = UUID.randomUUID();
        mockMvc.perform(authed(post("/sync/routines"), professorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of(routinePayload(rotina, professorId, "Rotina Privada Prof", now())))))
                .andExpect(status().isOk());

        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(get("/sync/routines"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.nome=='Rotina Privada Prof')]").doesNotExist());
    }

    // ---- autenticação ----

    @Test
    void pushSemAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(post("/sync/routines")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(toJson(List.of())))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void pullSemAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(get("/sync/routines")).andExpect(status().isUnauthorized());
    }

    @Test
    void tabelaDeSyncDesconhecidaRetorna422() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/sync/tabela_inexistente"), token))
                .andExpect(status().isUnprocessableEntity());
    }

    // ---- helpers ----

    private String now() {
        return OffsetDateTime.now(ZoneOffset.UTC).toString();
    }

    private Map<String, Object> routinePayload(UUID id, UUID userId, String nome, String updatedAt) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", id.toString());
        m.put("user_id", userId.toString());
        m.put("nome", nome);
        m.put("tipo", "fixo");
        m.put("dias_da_semana", List.of("seg", "qua", "sex"));
        m.put("ordem", 0);
        m.put("ativo", true);
        m.put("origem", "propria");
        m.put("atribuido_por", null);
        m.put("criado_em", updatedAt);
        m.put("updated_at", updatedAt);
        m.put("deleted_at", null);
        m.put("device_id", "device-teste");
        return m;
    }

    private Map<String, Object> routinePayload(UUID id, UUID userId, String nome, OffsetDateTime updatedAt) {
        return routinePayload(id, userId, nome, updatedAt.toString());
    }

    private String toJson(Object o) throws Exception {
        return objectMapper.writeValueAsString(o);
    }
}
