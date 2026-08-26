package br.gov.goias.secami.training.coaching;

import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.Roles;
import br.gov.goias.secami.training.TrainingTestSupport;
import br.gov.goias.secami.training.coaching.CoachDtos.CriarConviteRequest;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Coaching (SPEC §8.6 / §9.3): convites de vínculo professor↔aluno, resgate
 * por código (com regras de validade/usos-máx), e listagens "meus
 * alunos"/"meus treinadores" restritas ao usuário autenticado.
 */
class CoachingIntegrationTest extends TrainingTestSupport {

    @Autowired private ConviteRepository conviteRepository;

    @Test
    void professorGeraConviteEAlunoResgataVinculoFicaAtivo() throws Exception {
        String professorToken = loginAs("professor");
        String codigo = criarConvite(professorToken, null, null);
        assertThat(codigo).hasSize(6);

        String alunoToken = loginAs("aluno");
        resgatar(alunoToken, codigo).andExpect(status().isOk());

        mockMvc.perform(authed(get("/coach/students"), professorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value("ativo"))
                .andExpect(jsonPath("$[0].aluno.nome").value(devUser("aluno").getNome()));

        mockMvc.perform(authed(get("/coach/trainers"), alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].status").value("ativo"))
                .andExpect(jsonPath("$[0].professor.nome").value(devUser("professor").getNome()));
    }

    @Test
    void resgatarComCodigoInvalidoRetornaErro() throws Exception {
        String alunoToken = loginAs("aluno");
        resgatar(alunoToken, "ZZZZZZ").andExpect(status().isUnprocessableEntity());
    }

    @Test
    void resgatarConviteExpiradoRetornaErro() throws Exception {
        String professorToken = loginAs("professor");
        String codigo = criarConvite(professorToken, null, null);

        Convite convite = conviteRepository.findByCodigo(codigo).orElseThrow();
        convite.setExpiraEm(OffsetDateTime.now().minusDays(1));
        conviteRepository.save(convite);

        String alunoToken = loginAs("aluno");
        resgatar(alunoToken, codigo).andExpect(status().isUnprocessableEntity());
    }

    @Test
    void resgatarConviteJaEsgotadoRetornaErro() throws Exception {
        String professorToken = loginAs("professor");
        String codigo = criarConvite(professorToken, 1, null); // usosMax = 1 (default explícito)

        String aluno1Token = loginAs("aluno");
        resgatar(aluno1Token, codigo).andExpect(status().isOk());

        AppUser aluno2 = createDevUser(Roles.ALUNO);
        String aluno2Token = loginAs(aluno2.getSamAccountName());
        resgatar(aluno2Token, codigo).andExpect(status().isUnprocessableEntity());
    }

    @Test
    void resgatarPermiteMultiplosUsosAteLimite() throws Exception {
        String professorToken = loginAs("professor");
        String codigo = criarConvite(professorToken, 2, null);

        String aluno1Token = loginAs("aluno");
        resgatar(aluno1Token, codigo).andExpect(status().isOk());

        AppUser aluno2 = createDevUser(Roles.ALUNO);
        String aluno2Token = loginAs(aluno2.getSamAccountName());
        resgatar(aluno2Token, codigo).andExpect(status().isOk());

        mockMvc.perform(authed(get("/coach/students"), professorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2));
    }

    @Test
    void professorNaoPodeVincularASiMesmoUsandoOProprioConvite() throws Exception {
        String professorToken = loginAs("professor");
        String codigo = criarConvite(professorToken, null, null);

        resgatar(professorToken, codigo).andExpect(status().isUnprocessableEntity());
    }

    @Test
    void resgatarConviteParaVinculoJaExistenteRetornaConflito() throws Exception {
        String professorToken = loginAs("professor");
        String alunoToken = loginAs("aluno");

        String codigo1 = criarConvite(professorToken, null, null);
        resgatar(alunoToken, codigo1).andExpect(status().isOk());

        String codigo2 = criarConvite(professorToken, null, null);
        resgatar(alunoToken, codigo2).andExpect(status().isConflict());
    }

    @Test
    void listagensRetornamApenasVinculosDoUsuarioAutenticado() throws Exception {
        String professor1Token = loginAs("professor");
        String aluno1Token = loginAs("aluno");
        AppUser professor2 = createDevUser(Roles.PROFESSOR);
        AppUser aluno2 = createDevUser(Roles.ALUNO);
        String professor2Token = loginAs(professor2.getSamAccountName());
        String aluno2Token = loginAs(aluno2.getSamAccountName());

        resgatar(aluno1Token, criarConvite(professor1Token, null, null)).andExpect(status().isOk());
        resgatar(aluno2Token, criarConvite(professor2Token, null, null)).andExpect(status().isOk());

        mockMvc.perform(authed(get("/coach/students"), professor1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].aluno.nome").value(devUser("aluno").getNome()));

        mockMvc.perform(authed(get("/coach/students"), professor2Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].aluno.nome").value(aluno2.getNome()));

        mockMvc.perform(authed(get("/coach/trainers"), aluno1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].professor.nome").value(devUser("professor").getNome()));

        mockMvc.perform(authed(get("/coach/trainers"), aluno2Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].professor.nome").value(professor2.getNome()));
    }

    @Test
    void alunoNaoPodeCriarConvite() throws Exception {
        String alunoToken = loginAs("aluno");
        mockMvc.perform(authed(post("/coach/invites"), alunoToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CriarConviteRequest(null, null, null, null))))
                .andExpect(status().isForbidden());
    }

    @Test
    void recepcaoNaoPodeCriarConvite() throws Exception {
        String recepcaoToken = loginAs("recepcao");
        mockMvc.perform(authed(post("/coach/invites"), recepcaoToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CriarConviteRequest(null, null, null, null))))
                .andExpect(status().isForbidden());
    }

    @Test
    void adminPodeCriarConvite() throws Exception {
        String adminToken = loginAs("admin");
        mockMvc.perform(authed(post("/coach/invites"), adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CriarConviteRequest(null, null, null, null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.codigo").exists())
                .andExpect(jsonPath("$.expiraEm").exists());
    }

    @Test
    void criarConviteSemAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(post("/coach/invites").contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isUnauthorized());
    }

    // ---- helpers ----

    private String criarConvite(String professorToken, Integer usosMax, Integer validadeDias) throws Exception {
        String response = mockMvc.perform(authed(post("/coach/invites"), professorToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new CriarConviteRequest(null, null, usosMax, validadeDias))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        JsonNode json = objectMapper.readTree(response);
        return json.get("codigo").asText();
    }

    private org.springframework.test.web.servlet.ResultActions resgatar(String token, String codigo) throws Exception {
        return mockMvc.perform(authed(post("/coach/invites/redeem"), token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(new CoachDtos.ResgatarRequest(codigo))));
    }
}
