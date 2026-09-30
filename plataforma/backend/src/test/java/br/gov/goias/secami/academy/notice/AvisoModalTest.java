package br.gov.goias.secami.academy.notice;

import br.gov.goias.secami.AbstractIntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.time.ZoneId;
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
 * Aviso como janela no app: período de exibição (datas inclusive) e
 * "não mostrar novamente" por usuário ({@code GET /notices/modal},
 * {@code POST /notices/{id}/dispensar}).
 */
class AvisoModalTest extends AbstractIntegrationTest {

    @Autowired private NoticeRepository noticeRepository;

    private static LocalDate hoje() {
        return LocalDate.now(ZoneId.of("America/Sao_Paulo"));
    }

    private Notice aviso(LocalDate de, LocalDate ate) {
        Notice n = new Notice();
        n.setTitle("Aviso " + UUID.randomUUID());
        n.setContent("conteúdo");
        n.setType("info");
        n.setActive(true);
        n.setTargetRoles(new ArrayList<>(List.of("aluno", "professor")));
        n.setExibirDe(de);
        n.setExibirAte(ate);
        return noticeRepository.save(n);
    }

    private boolean contem(String rota, String token, Notice n) throws Exception {
        String json = mockMvc.perform(authed(get(rota), token))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        for (JsonNode item : objectMapper.readTree(json)) {
            if (item.get("id").asText().equals(n.getId().toString())) return true;
        }
        return false;
    }

    @Test
    void periodoDeExibicao_respeitaAsDatasInclusive() throws Exception {
        String aluno = loginAs("aluno");
        Notice semPeriodo = aviso(null, null);
        Notice comecaHoje = aviso(hoje(), null);
        Notice terminaHoje = aviso(null, hoje());
        Notice futuro = aviso(hoje().plusDays(1), hoje().plusDays(5));
        Notice encerrado = aviso(hoje().minusDays(5), hoje().minusDays(1));

        for (String rota : List.of("/notices/active", "/notices/modal")) {
            assertThat(contem(rota, aluno, semPeriodo)).as(rota).isTrue();
            assertThat(contem(rota, aluno, comecaHoje)).as(rota).isTrue();
            assertThat(contem(rota, aluno, terminaHoje)).as(rota).isTrue();
            assertThat(contem(rota, aluno, futuro)).as(rota).isFalse();
            assertThat(contem(rota, aluno, encerrado)).as(rota).isFalse();
        }
    }

    @Test
    void naoMostrarNovamente_tiraSoDaJanelaESoParaQuemMarcou() throws Exception {
        String aluno = loginAs("aluno");
        String professor = loginAs("professor");
        Notice n = aviso(null, null);

        mockMvc.perform(authed(post("/notices/" + n.getId() + "/dispensar"), aluno)).andExpect(status().isOk());
        // Repetir não dá erro (idempotente).
        mockMvc.perform(authed(post("/notices/" + n.getId() + "/dispensar"), aluno)).andExpect(status().isOk());

        assertThat(contem("/notices/modal", aluno, n)).isFalse();
        // Continua na tela "Avisos" de quem dispensou…
        assertThat(contem("/notices/active", aluno, n)).isTrue();
        // …e a janela continua aparecendo pra quem não dispensou.
        assertThat(contem("/notices/modal", professor, n)).isTrue();
    }

    @Test
    void dispensarAvisoInexistente_retorna404() throws Exception {
        mockMvc.perform(authed(post("/notices/" + UUID.randomUUID() + "/dispensar"), loginAs("aluno")))
                .andExpect(status().isNotFound());
    }

    @Test
    void criarComPeriodoInvertido_retorna422() throws Exception {
        String corpo = """
                {"title":"Período errado","content":"x","type":"info","active":true,"targetRoles":["aluno"],
                 "exibirDe":"%s","exibirAte":"%s"}""".formatted(hoje().plusDays(3), hoje());
        mockMvc.perform(authed(post("/notices"), loginAs("admin"))
                        .contentType(MediaType.APPLICATION_JSON).content(corpo))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void criarEditarPeriodo_eExcluirAvisoJaDispensado() throws Exception {
        String admin = loginAs("admin");
        String corpo = """
                {"title":"Semana da saúde","content":"x","type":"success","active":true,"targetRoles":["aluno"],
                 "exibirDe":"%s","exibirAte":"%s"}""";
        String criado = mockMvc.perform(authed(post("/notices"), admin).contentType(MediaType.APPLICATION_JSON)
                        .content(corpo.formatted(hoje(), hoje().plusDays(7))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exibirDe").value(hoje().toString()))
                .andExpect(jsonPath("$.exibirAte").value(hoje().plusDays(7).toString()))
                .andReturn().getResponse().getContentAsString();
        String id = objectMapper.readTree(criado).get("id").asText();

        // Editar sem datas limpa o período.
        mockMvc.perform(authed(put("/notices/" + id), admin).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"title\":\"Semana da saúde\",\"content\":\"y\",\"type\":\"success\",\"active\":true,"
                                + "\"targetRoles\":[\"aluno\"]}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exibirDe").doesNotExist())
                .andExpect(jsonPath("$.content").value("y"));

        mockMvc.perform(authed(post("/notices/" + id + "/dispensar"), loginAs("aluno"))).andExpect(status().isOk());
        mockMvc.perform(authed(delete("/notices/" + id), admin)).andExpect(status().isOk());
        assertThat(noticeRepository.findById(UUID.fromString(id))).isEmpty();
    }
}
