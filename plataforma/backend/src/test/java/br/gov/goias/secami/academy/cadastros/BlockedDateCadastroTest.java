package br.gov.goias.secami.academy.cadastros;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.slot.BlockedDate;
import br.gov.goias.secami.academy.slot.BlockedDateRepository;
import br.gov.goias.secami.academy.slot.SlotDtos.BlockedDateCreate;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Testes de integração de /blocked-dates (bloqueio de dia inteiro ou de um
 * slot específico). SPEC §8.3, §9.3, §11.1.
 */
class BlockedDateCadastroTest extends AbstractIntegrationTest {

    @Autowired BlockedDateRepository blockedDates;

    @Test
    void bloquearDiaInteiro_slotStartAusenteNaResposta() throws Exception {
        String token = loginAs("admin");
        LocalDate data = LocalDate.now().plusDays(10);

        mockMvc.perform(authed(post("/blocked-dates"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new BlockedDateCreate(data, null, "Feriado"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.date").value(data.toString()))
                .andExpect(jsonPath("$.slotStart").doesNotExist())
                .andExpect(jsonPath("$.reason").value("Feriado"));
    }

    @Test
    void bloquearSlotEspecifico_slotStartPreenchidoNaResposta() throws Exception {
        String token = loginAs("gerente");
        LocalDate data = LocalDate.now().plusDays(11);

        mockMvc.perform(authed(post("/blocked-dates"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new BlockedDateCreate(data, "08:00", "Manutenção do equipamento"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.date").value(data.toString()))
                .andExpect(jsonPath("$.slotStart").value("08:00"))
                .andExpect(jsonPath("$.reason").value("Manutenção do equipamento"));
    }

    @Test
    void listagemIgnoraDatasPassadasEMostraSomenteFuturas() throws Exception {
        BlockedDate passado = saveBlockedDate(LocalDate.now().minusDays(5), null, "Já passou");
        BlockedDate futuro = saveBlockedDate(LocalDate.now().plusDays(5), null, "Vai acontecer");
        String token = loginAs("professor");

        String json = mockMvc.perform(authed(get("/blocked-dates"), token))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        JsonNode arr = objectMapper.readTree(json);

        List<String> ids = new ArrayList<>();
        for (JsonNode n : arr) {
            ids.add(n.get("id").asText());
            assertThat(LocalDate.parse(n.get("date").asText())).isAfterOrEqualTo(LocalDate.now());
        }
        assertThat(ids).contains(futuro.getId().toString());
        assertThat(ids).doesNotContain(passado.getId().toString());
    }

    @Test
    void excluirDataBloqueadaComoAdmin_remove() throws Exception {
        BlockedDate b = saveBlockedDate(LocalDate.now().plusDays(3), null, "Remover");
        String token = loginAs("admin");

        mockMvc.perform(authed(delete("/blocked-dates/" + b.getId()), token)).andExpect(status().isOk());
        assertThat(blockedDates.findById(b.getId())).isEmpty();
    }

    @Test
    void criarDataBloqueadaSemData_retorna400() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/blocked-dates"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"slotStart\":\"08:00\",\"reason\":\"sem data\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fieldErrors[?(@.field=='date')]").exists());
    }

    @Test
    void alunoPodeListarDatasBloqueadas() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/blocked-dates"), token)).andExpect(status().isOk());
    }

    @Test
    void recepcaoNaoPodeCriarDataBloqueada() throws Exception {
        String token = loginAs("recepcao");
        mockMvc.perform(authed(post("/blocked-dates"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new BlockedDateCreate(LocalDate.now().plusDays(1), null, null))))
                .andExpect(status().isForbidden());
    }

    @Test
    void professorNaoPodeExcluirDataBloqueada() throws Exception {
        BlockedDate b = saveBlockedDate(LocalDate.now().plusDays(2), null, "Protegido");
        String token = loginAs("professor");

        mockMvc.perform(authed(delete("/blocked-dates/" + b.getId()), token)).andExpect(status().isForbidden());
        assertThat(blockedDates.findById(b.getId())).isPresent();
    }

    @Test
    void alunoNaoPodeCriarDataBloqueada() throws Exception {
        String token = loginAs("aluno");
        mockMvc.perform(authed(post("/blocked-dates"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new BlockedDateCreate(LocalDate.now().plusDays(1), "08:00", null))))
                .andExpect(status().isForbidden());
    }

    private BlockedDate saveBlockedDate(LocalDate date, String slotStart, String reason) {
        BlockedDate b = new BlockedDate();
        b.setDate(date);
        b.setSlotStart(slotStart);
        b.setReason(reason);
        return blockedDates.save(b);
    }
}
