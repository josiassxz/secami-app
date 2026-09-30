package br.gov.goias.secami.academy.cadastros;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.slot.SlotConfig;
import br.gov.goias.secami.academy.slot.SlotConfigRepository;
import br.gov.goias.secami.academy.slot.SlotDtos.SlotConfigUpsert;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Testes de integração de /slot-configs (configuração de horário/capacidade
 * civil-militar). SPEC §8.3, §9.3, §11.1.
 */
class SlotConfigCadastroTest extends AbstractIntegrationTest {

    @Autowired SlotConfigRepository slots;

    @Test
    void criarSlot_persisteCapacidadeEFlags() throws Exception {
        String token = loginAs("admin");
        postSlot(token, "08:00", "09:00", 30, true, false, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.slotStart").value("08:00"))
                .andExpect(jsonPath("$.slotEnd").value("09:00"))
                .andExpect(jsonPath("$.maxCapacity").value(30))
                .andExpect(jsonPath("$.civilRestricted").value(true))
                .andExpect(jsonPath("$.blocked").value(false));
    }

    @Test
    void criarSlotDuasVezesComMesmoHorario_atualizaEmVezDeDuplicar() throws Exception {
        String token = loginAs("admin");
        String slotStart = "13:00";

        postSlot(token, slotStart, "14:00", 20, false, false, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxCapacity").value(20));

        postSlot(token, slotStart, "14:00", 35, true, false, null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxCapacity").value(35))
                .andExpect(jsonPath("$.civilRestricted").value(true));

        long total = slots.findAllByOrderBySlotStartAsc().stream()
                .filter(s -> slotStart.equals(s.getSlotStart()))
                .count();
        assertThat(total).isEqualTo(1);
    }

    @Test
    void editarSlotPorId_atualizaCapacidadeEFlagsDeBloqueio() throws Exception {
        SlotConfig s = saveSlot("10:00", "11:00", 40, false, false, null);
        String token = loginAs("gerente");

        mockMvc.perform(authed(put("/slot-configs/" + s.getId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new SlotConfigUpsert("10:00", "11:00", 15, true, true, "Manutenção do equipamento"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxCapacity").value(15))
                .andExpect(jsonPath("$.civilRestricted").value(true))
                .andExpect(jsonPath("$.blocked").value(true))
                .andExpect(jsonPath("$.blockReason").value("Manutenção do equipamento"));

        SlotConfig persisted = slots.findById(s.getId()).orElseThrow();
        assertThat(persisted.getMaxCapacity()).isEqualTo(15);
        assertThat(persisted.isCivilRestricted()).isTrue();
        assertThat(persisted.isBlocked()).isTrue();
    }

    @Test
    void editarSlotInexistente_retorna404() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(put("/slot-configs/" + UUID.randomUUID()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new SlotConfigUpsert("07:00", "08:00", null, null, null, null))))
                .andExpect(status().isNotFound());
    }

    @Test
    void criarSlotSemHorarioInicial_retorna400() throws Exception {
        String token = loginAs("admin");
        mockMvc.perform(authed(post("/slot-configs"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new SlotConfigUpsert("", "09:00", null, null, null, null))))
                .andExpect(status().isBadRequest());
    }

    @Test
    void criarSlotComFormatoDeHorarioInvalido_retorna400() throws Exception {
        String token = loginAs("admin");
        postSlot(token, "9h", "10:00", null, null, null, null)
                .andExpect(status().isBadRequest());
    }

    @Test
    void criarSlotComHorarioFinalAntesDoInicial_retorna422() throws Exception {
        String token = loginAs("admin");
        postSlot(token, "10:00", "09:00", null, null, null, null)
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void editarSlotParaHorarioDeOutroSlotJaExistente_retorna409() throws Exception {
        saveSlot("11:00", "12:00", 40, false, false, null);
        SlotConfig alvo = saveSlot("18:00", "19:00", 40, false, false, null);
        String token = loginAs("admin");

        mockMvc.perform(authed(put("/slot-configs/" + alvo.getId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new SlotConfigUpsert("11:00", "12:00", null, null, null, null))))
                .andExpect(status().isConflict());
    }

    @Test
    void editarSlotMantendoOMesmoHorario_naoConflitaComEleMesmo() throws Exception {
        SlotConfig s = saveSlot("19:00", "20:00", 40, false, false, null);
        String token = loginAs("admin");

        mockMvc.perform(authed(put("/slot-configs/" + s.getId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new SlotConfigUpsert("19:00", "20:00", 50, null, null, null))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxCapacity").value(50));
    }

    @Test
    void listagemDeSlotsAcessivelATodosOsPapeisAutenticados() throws Exception {
        saveSlot("06:00", "07:00", 40, false, false, null);
        for (String role : new String[] {"admin", "gerente", "recepcao", "professor", "aluno"}) {
            String token = loginAs(role);
            mockMvc.perform(authed(get("/slot-configs"), token)).andExpect(status().isOk());
        }
    }

    @Test
    void recepcaoNaoPodeCriarSlot() throws Exception {
        String token = loginAs("recepcao");
        postSlot(token, "15:00", "16:00", 20, false, false, null).andExpect(status().isForbidden());
    }

    @Test
    void professorNaoPodeEditarSlot() throws Exception {
        SlotConfig s = saveSlot("16:00", "17:00", 20, false, false, null);
        String token = loginAs("professor");
        mockMvc.perform(authed(put("/slot-configs/" + s.getId()), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new SlotConfigUpsert("16:00", "17:00", 99, null, null, null))))
                .andExpect(status().isForbidden());
    }

    @Test
    void alunoNaoPodeCriarSlot() throws Exception {
        String token = loginAs("aluno");
        postSlot(token, "17:00", "18:00", 20, false, false, null).andExpect(status().isForbidden());
    }

    private ResultActions postSlot(String token, String slotStart, String slotEnd, Integer maxCapacity,
                                    Boolean civilRestricted, Boolean blocked, String blockReason) throws Exception {
        return mockMvc.perform(authed(post("/slot-configs"), token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(
                        new SlotConfigUpsert(slotStart, slotEnd, maxCapacity, civilRestricted, blocked, blockReason))));
    }

    private SlotConfig saveSlot(String start, String end, int cap, boolean civilRestricted,
                                 boolean blocked, String reason) {
        SlotConfig s = new SlotConfig();
        s.setSlotStart(start);
        s.setSlotEnd(end);
        s.setMaxCapacity(cap);
        s.setCivilRestricted(civilRestricted);
        s.setBlocked(blocked);
        s.setBlockReason(reason);
        return slots.save(s);
    }
}
