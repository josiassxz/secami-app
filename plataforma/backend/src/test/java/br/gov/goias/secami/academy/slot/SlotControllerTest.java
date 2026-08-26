package br.gov.goias.secami.academy.slot;

import br.gov.goias.secami.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Grade de horários (SPEC §8.3 / §9.4) — leitura de {@code /slot-configs}
 * (janelas de 1h de agendamento) e {@code /blocked-dates} (bloqueios).
 * Escrita (admin/gerente) fica a cargo do CRUD já coberto em outra área;
 * aqui o foco é a consulta que o app/admin usa para montar a grade do dia.
 */
class SlotControllerTest extends AbstractIntegrationTest {

    @Autowired private SlotConfigRepository slotConfigRepository;
    @Autowired private BlockedDateRepository blockedDateRepository;

    @Test
    void listaDeSlotsVemOrdenadaPorHorarioDeInicio() throws Exception {
        criarSlot("10:00", "11:00");
        criarSlot("07:00", "08:00");
        criarSlot("08:30", "09:30");

        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/slot-configs"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].slotStart").value("07:00"))
                .andExpect(jsonPath("$[1].slotStart").value("08:30"))
                .andExpect(jsonPath("$[2].slotStart").value("10:00"));
    }

    @Test
    void listaDeSlotsExpoeCapacidadeERestricoes() throws Exception {
        SlotConfig s = new SlotConfig();
        s.setSlotStart("06:00");
        s.setSlotEnd("07:00");
        s.setMaxCapacity(15);
        s.setCivilRestricted(true);
        s.setBlocked(false);
        slotConfigRepository.save(s);

        String token = loginAs("recepcao");
        mockMvc.perform(authed(get("/slot-configs"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.slotStart=='06:00')].maxCapacity").value(15))
                .andExpect(jsonPath("$[?(@.slotStart=='06:00')].civilRestricted").value(true));
    }

    @Test
    void listaDeSlotsSemAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(get("/slot-configs")).andExpect(status().isUnauthorized());
    }

    @Test
    void datasBloqueadasNoPassadoNaoAparecemNaListagem() throws Exception {
        LocalDate ontem = LocalDate.now().minusDays(1);
        LocalDate amanha = LocalDate.now().plusDays(1);

        BlockedDate passado = new BlockedDate();
        passado.setDate(ontem);
        passado.setReason("Feriado já passado — não deve aparecer");
        blockedDateRepository.save(passado);

        BlockedDate futuro = new BlockedDate();
        futuro.setDate(amanha);
        futuro.setReason("Manutenção futura");
        blockedDateRepository.save(futuro);

        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/blocked-dates"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.reason=='Feriado já passado — não deve aparecer')]").doesNotExist())
                .andExpect(jsonPath("$[?(@.reason=='Manutenção futura')]").exists());
    }

    @Test
    void dataBloqueadaHojeAindaApareceNaListagem() throws Exception {
        BlockedDate hoje = new BlockedDate();
        hoje.setDate(LocalDate.now());
        hoje.setReason("Bloqueio de hoje mesmo");
        blockedDateRepository.save(hoje);

        String token = loginAs("aluno");
        mockMvc.perform(authed(get("/blocked-dates"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[?(@.reason=='Bloqueio de hoje mesmo')]").exists());
    }

    @Test
    void datasBloqueadasSemAutenticacaoRetorna401() throws Exception {
        mockMvc.perform(get("/blocked-dates")).andExpect(status().isUnauthorized());
    }

    private void criarSlot(String start, String end) {
        SlotConfig s = new SlotConfig();
        s.setSlotStart(start);
        s.setSlotEnd(end);
        slotConfigRepository.save(s);
    }
}
