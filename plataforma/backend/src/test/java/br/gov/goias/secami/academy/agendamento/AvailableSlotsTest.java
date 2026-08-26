package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.student.Student;
import org.junit.jupiter.api.Test;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * SPEC §9.4 — oferta de slots ao aluno (GET /me/appointments/available).
 *
 * <p>Um slot só é ofertado (available=true) se TODAS as condições abaixo forem
 * verdadeiras: (1) {@code slotDateTime > agora e <= agora+48h}; (2)
 * {@code slot_config.blocked=false}; (3) NÃO ({@code student_type=Civil} E
 * {@code slot_config.civil_restricted}); (4) sem {@code blocked_date} para a
 * data/slot. Cada teste aqui viola exatamente UMA condição, mantendo as demais
 * válidas — cada cenário cria um único slot_config, então a resposta tem
 * exatamente 1 elemento (índice 0).
 */
class AvailableSlotsTest extends SchedulingTestSupport {

    private String linkAluno(String tipo) throws Exception {
        Student s = newStudent(tipo);
        vinculadoAoUsuario(s, appUserId("aluno"));
        return loginAs("aluno");
    }

    @Test
    void slotValidoDentroDaJanelaEOfertado() throws Exception {
        String token = linkAluno("Civil");
        slotAberto("08:00");
        mockMvc.perform(authed(get("/me/appointments/available").param("date", amanha().toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].slotStart").value("08:00"))
                .andExpect(jsonPath("$[0].available").value(true))
                .andExpect(jsonPath("$[0].reason").doesNotExist());
    }

    // ---- Condição 1: janela de 48h ----

    @Test
    void condicao1_slotNoPassadoNaoEOfertado() throws Exception {
        String token = linkAluno("Civil");
        slotAberto("08:00");
        mockMvc.perform(authed(get("/me/appointments/available").param("date", ontem().toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].available").value(false))
                .andExpect(jsonPath("$[0].reason").value("Horário já passou"));
    }

    @Test
    void condicao1_slotAlemDe48hNaoEOfertado() throws Exception {
        String token = linkAluno("Civil");
        slotAberto("08:00");
        mockMvc.perform(authed(get("/me/appointments/available").param("date", foraDaJanela().toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].available").value(false))
                .andExpect(jsonPath("$[0].reason").value("Fora da janela de 48h"));
    }

    // ---- Condição 2: slot_config.blocked ----

    @Test
    void condicao2_slotBloqueadoNaoEOfertado() throws Exception {
        String token = linkAluno("Civil");
        slot("08:00", 40, false, true); // blocked=true, blockReason="Manutenção"
        mockMvc.perform(authed(get("/me/appointments/available").param("date", amanha().toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].available").value(false))
                .andExpect(jsonPath("$[0].reason").value("Manutenção"));
    }

    // ---- Condição 3: civil_restricted só afeta Civil ----

    @Test
    void condicao3_civilRestritoNaoEOfertadoParaCivil() throws Exception {
        String token = linkAluno("Civil");
        slot("08:00", 40, true, false); // civilRestricted=true
        mockMvc.perform(authed(get("/me/appointments/available").param("date", amanha().toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].available").value(false))
                .andExpect(jsonPath("$[0].reason").value("Restrito a militares"));
    }

    @Test
    void condicao3_civilRestritoEOfertadoParaMilitar() throws Exception {
        String token = linkAluno("Militar");
        slot("08:00", 40, true, false); // civilRestricted=true
        mockMvc.perform(authed(get("/me/appointments/available").param("date", amanha().toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].available").value(true))
                .andExpect(jsonPath("$[0].reason").doesNotExist());
    }

    // ---- Condição 4: blocked_date (dia inteiro ou slot específico) ----

    @Test
    void condicao4_diaInteiroBloqueadoNaoEOfertado() throws Exception {
        String token = linkAluno("Civil");
        slotAberto("08:00");
        blockDay(amanha());
        mockMvc.perform(authed(get("/me/appointments/available").param("date", amanha().toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].available").value(false))
                .andExpect(jsonPath("$[0].reason").value("Data bloqueada"));
    }

    @Test
    void condicao4_slotEspecificoBloqueadoNaoEOfertado() throws Exception {
        String token = linkAluno("Civil");
        slotAberto("08:00");
        blockSlot(amanha(), "08:00");
        mockMvc.perform(authed(get("/me/appointments/available").param("date", amanha().toString()), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].available").value(false))
                .andExpect(jsonPath("$[0].reason").value("Horário bloqueado nesta data"));
    }
}
