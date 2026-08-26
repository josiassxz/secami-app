package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Fluxo feliz ponta a ponta (SPEC §9.4/§9.5), passando pela pilha real
 * (controller → security → service → repository → Postgres) do início ao fim:
 * aluno consulta disponibilidade → agenda → recepção faz check-in (vincula e
 * confirma o agendamento) → recepção faz check-out.
 */
class SchedulingEndToEndTest extends SchedulingTestSupport {

    @Test
    void agendarCheckInECheckOut_fluxoCompleto() throws Exception {
        // Aluno civil com foto e atestado válido, vinculado à conta "aluno".
        Student student = newStudent("Civil");
        comFoto(student);
        comAtestado(student, hoje().minusMonths(2));
        vinculadoAoUsuario(student, appUserId("aluno"));
        String alunoToken = loginAs("aluno");
        slotAberto("08:00");

        // 1) Consulta de disponibilidade: o slot de amanhã deve estar ofertado.
        mockMvc.perform(authed(
                        org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                                .get("/me/appointments/available")
                                .param("date", amanha().toString()),
                        alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].available").value(true));

        // 2) Agendamento pelo próprio aluno.
        JsonNode booked = readJson(bookAsStudent(alunoToken, amanha(), "08:00")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(Appointment.AGENDADO))
                .andExpect(jsonPath("$.forced").value(false)));
        UUID appointmentId = UUID.fromString(booked.get("id").asText());

        // Aparece na lista "meus agendamentos" do aluno.
        mockMvc.perform(authed(
                        org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/me/appointments"),
                        alunoToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(appointmentId.toString()));

        // 3) Check-in pela recepção no dia do agendamento — vincula e confirma.
        String staffToken = loginAs("recepcao");
        JsonNode checkIn = readJson(doCheckIn(staffToken, student.getId(), amanha(), null)
                .andExpect(status().isOk()));
        UUID checkInId = UUID.fromString(checkIn.get("id").asText());
        assertEquals(appointmentId.toString(), checkIn.get("appointmentId").asText());

        Appointment afterCheckIn = appointmentRepository.findById(appointmentId).orElseThrow();
        assertEquals(Appointment.CONFIRMADO, afterCheckIn.getStatus());

        // 4) Check-out.
        JsonNode afterCheckout = readJson(doCheckOut(staffToken, checkInId).andExpect(status().isOk()));
        org.junit.jupiter.api.Assertions.assertTrue(afterCheckout.get("checkOutTime").asText().matches("\\d{2}:\\d{2}"));
    }
}
