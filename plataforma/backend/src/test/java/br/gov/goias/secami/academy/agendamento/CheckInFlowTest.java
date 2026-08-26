package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.checkin.CheckIn;
import br.gov.goias.secami.academy.student.Student;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * SPEC §9.5 — presença: check-in manual, check-out, falta e desfazer-falta/check-in.
 * Console operado pela recepção/professor/admin (CheckInController).
 */
class CheckInFlowTest extends SchedulingTestSupport {

    @Test
    void checkInManualVinculaAoAgendamentoDoDiaEConfirma() throws Exception {
        Student s = civil();
        Appointment appt = seedAppointment(s, hoje(), "08:00", Appointment.AGENDADO);

        String staffToken = loginAs("recepcao");
        JsonNode resp = readJson(doCheckIn(staffToken, s.getId(), hoje(), null).andExpect(status().isOk()));

        assertEquals(appt.getId().toString(), resp.get("appointmentId").asText());
        assertTrue(resp.get("checkInTime").asText().matches("\\d{2}:\\d{2}"));

        Appointment reloaded = appointmentRepository.findById(appt.getId()).orElseThrow();
        assertEquals(Appointment.CONFIRMADO, reloaded.getStatus());
    }

    @Test
    void checkInSemAgendamento_naoVinculaMasCriaORegistro() throws Exception {
        Student s = civil(); // sem nenhum agendamento hoje

        String staffToken = loginAs("recepcao");
        JsonNode resp = readJson(doCheckIn(staffToken, s.getId(), hoje(), "walk-in").andExpect(status().isOk()));

        // appointmentId ausente do JSON (serializador omite campos nulos) == sem vínculo.
        assertNull(resp.get("appointmentId"));
        assertEquals(s.getId().toString(), resp.get("studentId").asText());
    }

    @Test
    void checkInDuplicadoNoMesmoDia_bloqueado() throws Exception {
        Student s = civil();
        String staffToken = loginAs("recepcao");
        doCheckIn(staffToken, s.getId(), hoje(), null).andExpect(status().isOk());

        doCheckIn(staffToken, s.getId(), hoje(), null)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Aluno já possui check-in nesta data."));
    }

    @Test
    void checkOutGravaHorarioDeSaida() throws Exception {
        Student s = civil();
        String staffToken = loginAs("recepcao");
        JsonNode created = readJson(doCheckIn(staffToken, s.getId(), hoje(), null).andExpect(status().isOk()));
        UUID checkInId = UUID.fromString(created.get("id").asText());
        assertNull(created.get("checkOutTime"));

        JsonNode afterCheckout = readJson(doCheckOut(staffToken, checkInId).andExpect(status().isOk()));
        assertTrue(afterCheckout.get("checkOutTime").asText().matches("\\d{2}:\\d{2}"));
    }

    @Test
    void desfazerCheckIn_apagaORegistro() throws Exception {
        Student s = civil();
        String staffToken = loginAs("recepcao");
        JsonNode created = readJson(doCheckIn(staffToken, s.getId(), hoje(), null).andExpect(status().isOk()));
        UUID checkInId = UUID.fromString(created.get("id").asText());

        undoCheckIn(staffToken, checkInId).andExpect(status().isOk());

        assertTrue(checkInRepository.findById(checkInId).isEmpty());
    }

    @Test
    void marcarFalta_mudaStatusParaFaltouEDesfazerFaltaVoltaParaAgendado() throws Exception {
        Student s = civil();
        Appointment appt = seedAppointment(s, ontem(), "08:00", Appointment.AGENDADO);
        String staffToken = loginAs("recepcao");

        marcarFalta(staffToken, appt.getId()).andExpect(status().isOk());
        assertEquals(Appointment.FALTOU, appointmentRepository.findById(appt.getId()).orElseThrow().getStatus());

        desfazerFalta(staffToken, appt.getId()).andExpect(status().isOk());
        assertEquals(Appointment.AGENDADO, appointmentRepository.findById(appt.getId()).orElseThrow().getStatus());
    }
}
