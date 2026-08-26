package br.gov.goias.secami.academy.notice;

import br.gov.goias.secami.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Avisos por papel (SPEC §8.7 / §11.2) — {@code GET /notices/active} filtra
 * pelos papéis do usuário autenticado; escrita é admin/gerente.
 */
class NoticeControllerTest extends AbstractIntegrationTest {

    @Autowired private NoticeRepository noticeRepository;

    @Test
    void avisoSoParaProfessorNaoApareceParaAluno() throws Exception {
        String titulo = "Aviso restrito professor " + UUID.randomUUID();
        criarAviso(titulo, List.of("professor"), true);

        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(get("/notices/active"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").doesNotExist());

        String professorToken = loginAs("professor");
        mockMvc.perform(authed(get("/notices/active"), professorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").exists());
    }

    @Test
    void avisoSoParaAlunoNaoApareceParaProfessor() throws Exception {
        String titulo = "Aviso restrito aluno " + UUID.randomUUID();
        criarAviso(titulo, List.of("aluno"), true);

        String professorToken = loginAs("professor");
        mockMvc.perform(authed(get("/notices/active"), professorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").doesNotExist());

        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(get("/notices/active"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").exists());
    }

    @Test
    void avisoComMultiplosPapeisAlvoApareceParaTodosEles() throws Exception {
        String titulo = "Aviso professor e gerente " + UUID.randomUUID();
        criarAviso(titulo, List.of("professor", "gerente"), true);

        mockMvc.perform(authed(get("/notices/active"), loginAs("professor")))
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").exists());
        mockMvc.perform(authed(get("/notices/active"), loginAs("gerente")))
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").exists());
        mockMvc.perform(authed(get("/notices/active"), loginAs("aluno")))
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").doesNotExist());
    }

    @Test
    void avisoSemPapelAlvoDefinidoApareceParaTodosOsPapeis() throws Exception {
        String titulo = "Aviso geral " + UUID.randomUUID();
        criarAviso(titulo, new ArrayList<>(), true);

        mockMvc.perform(authed(get("/notices/active"), loginAs("aluno")))
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").exists());
        mockMvc.perform(authed(get("/notices/active"), loginAs("recepcao")))
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").exists());
    }

    @Test
    void avisoInativoNaoApareceMesmoParaPapelAlvo() throws Exception {
        String titulo = "Aviso inativo " + UUID.randomUUID();
        criarAviso(titulo, List.of("aluno"), false);

        mockMvc.perform(authed(get("/notices/active"), loginAs("aluno")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.title=='" + titulo + "')]").doesNotExist());
    }

    @Test
    void criarAvisoComoGerenteEhAceitoEFicaVisivelParaOPapelAlvo() throws Exception {
        String token = loginAs("gerente");
        String body = objectMapper.writeValueAsString(new NoticeDtos.UpsertRequest(
                "Manutenção da academia", "Fechado das 12h às 13h", "warning", true, List.of("aluno")));

        mockMvc.perform(authed(post("/notices"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.title").value("Manutenção da academia"))
                .andExpect(jsonPath("$.targetRoles[0]").value("aluno"));
    }

    @Test
    void alunoNaoPodeCriarAviso() throws Exception {
        String token = loginAs("aluno");
        String body = objectMapper.writeValueAsString(new NoticeDtos.UpsertRequest(
                "Tentativa indevida", "conteúdo", "info", true, List.of("aluno")));

        mockMvc.perform(authed(post("/notices"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body))
                .andExpect(status().isForbidden());
    }

    @Test
    void listarTodosRequerAdminOuGerente() throws Exception {
        mockMvc.perform(authed(get("/notices"), loginAs("professor")))
                .andExpect(status().isForbidden());
        mockMvc.perform(authed(get("/notices"), loginAs("admin")))
                .andExpect(status().isOk());
    }

    @Test
    void listarAvisosAtivosSemAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(get("/notices/active")).andExpect(status().isUnauthorized());
    }

    private void criarAviso(String title, List<String> targetRoles, boolean active) {
        Notice n = new Notice();
        n.setTitle(title);
        n.setContent("conteúdo de teste");
        n.setType("info");
        n.setActive(active);
        n.setTargetRoles(new ArrayList<>(targetRoles));
        Notice saved = noticeRepository.save(n);
        assertThat(saved.getId()).isNotNull();
    }
}
