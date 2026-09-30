package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.checkin.CheckIn;
import br.gov.goias.secami.academy.student.Student;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import java.time.OffsetDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** GET /checkins/resumo — visão do dia pra recepção/admin: agendamento (com
 *  quem faltou), check-in autodeclarado e confirmação real da catraca. */
class CheckInResumoTest extends SchedulingTestSupport {

    private JsonNode linhaDoAluno(JsonNode resumo, Student aluno) {
        for (JsonNode n : resumo) {
            if (n.get("studentId").asText().equals(aluno.getId().toString())) return n;
        }
        return null;
    }

    @Test
    void incluiAgendamentoComCheckInVinculado() throws Exception {
        Student s = civil();
        Appointment appt = seedAppointment(s, hoje(), "08:00", Appointment.CONFIRMADO);
        seedCheckIn(s, hoje(), appt.getId());

        String token = loginAs("recepcao");
        JsonNode resumo = readJson(mockMvc.perform(authed(get("/checkins/resumo?date=" + hoje()), token))
                .andExpect(status().isOk()));

        JsonNode linha = linhaDoAluno(resumo, s);
        assertEquals(appt.getId().toString(), linha.get("appointmentId").asText());
        assertEquals("confirmado", linha.get("status").asText());
        assertTrue(linha.get("checkInTime").asText().matches("\\d{2}:\\d{2}"));
    }

    @Test
    void incluiFaltaSemCheckIn() throws Exception {
        Student s = civil();
        seedAppointment(s, hoje(), "09:00", Appointment.FALTOU);

        String token = loginAs("admin");
        JsonNode resumo = readJson(mockMvc.perform(authed(get("/checkins/resumo?date=" + hoje()), token))
                .andExpect(status().isOk()));

        JsonNode linha = linhaDoAluno(resumo, s);
        assertEquals("faltou", linha.get("status").asText());
        // Serializador omite campos nulos — ausente do JSON == sem check-in.
        assertTrue(linha.get("checkInId") == null);
    }

    @Test
    void incluiVisitaEspontaneaSemAgendamento() throws Exception {
        Student s = civil(); // sem nenhum agendamento hoje
        seedCheckIn(s, hoje(), null);

        String token = loginAs("professor");
        JsonNode resumo = readJson(mockMvc.perform(authed(get("/checkins/resumo?date=" + hoje()), token))
                .andExpect(status().isOk()));

        JsonNode linha = linhaDoAluno(resumo, s);
        assertTrue(linha.get("appointmentId") == null);
        assertTrue(linha.get("checkInTime").asText().matches("\\d{2}:\\d{2}"));
    }

    @Test
    void omiteAgendamentoCancelado() throws Exception {
        Student s = civil();
        seedAppointment(s, hoje(), "10:00", Appointment.CANCELADO);

        String token = loginAs("admin");
        JsonNode resumo = readJson(mockMvc.perform(authed(get("/checkins/resumo?date=" + hoje()), token))
                .andExpect(status().isOk()));

        assertTrue(linhaDoAluno(resumo, s) == null);
    }

    @Test
    void calculaPermanenciaQuandoEntradaESaidaForamConfirmadasPelaCatraca() throws Exception {
        Student s = civil();
        Appointment appt = seedAppointment(s, hoje(), "08:00", Appointment.CONFIRMADO);
        appt.setEntradaConfirmadaEm(OffsetDateTime.now().minusHours(2));
        appt.setSaidaConfirmadaEm(OffsetDateTime.now().minusHours(1)); // 60min depois
        appointmentRepository.save(appt);

        String token = loginAs("admin");
        JsonNode resumo = readJson(mockMvc.perform(authed(get("/checkins/resumo?date=" + hoje()), token))
                .andExpect(status().isOk()));

        JsonNode linha = linhaDoAluno(resumo, s);
        assertEquals(60L, linha.get("permanenciaMinutos").asLong());
    }

    @Test
    void naoMostraPermanenciaQuandoSaidaVemAntesDaEntrada() throws Exception {
        // Visto em produção: a catraca real ocasionalmente grava entrada/saída
        // a poucos segundos uma da outra e fora de ordem — melhor omitir a
        // permanência do que mostrar um valor negativo.
        Student s = civil();
        Appointment appt = seedAppointment(s, hoje(), "08:00", Appointment.CONFIRMADO);
        appt.setEntradaConfirmadaEm(OffsetDateTime.now());
        appt.setSaidaConfirmadaEm(OffsetDateTime.now().minusSeconds(4));
        appointmentRepository.save(appt);

        String token = loginAs("admin");
        JsonNode resumo = readJson(mockMvc.perform(authed(get("/checkins/resumo?date=" + hoje()), token))
                .andExpect(status().isOk()));

        JsonNode linha = linhaDoAluno(resumo, s);
        assertTrue(linha.get("permanenciaMinutos") == null);
    }
}
