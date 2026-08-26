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
 * SPEC §9.4 — cancelamento (DELETE /appointments/{id}): soft-delete via
 * {@code status=cancelado}; um agendamento cancelado volta a contar como vaga livre.
 */
class CancelAppointmentTest extends SchedulingTestSupport {

    private Student alunoValido(String tipo) {
        Student s = newStudent(tipo);
        comFoto(s);
        if ("Civil".equalsIgnoreCase(tipo)) {
            comAtestado(s, hoje().minusMonths(1));
        }
        return s;
    }

    @Test
    void alunoCancelaProprioAgendamento_marcaStatusCancelado() throws Exception {
        Student s = alunoValido("Civil");
        vinculadoAoUsuario(s, appUserId("aluno"));
        String token = loginAs("aluno");
        slotAberto("08:00");

        JsonNode created = readJson(bookAsStudent(token, amanha(), "08:00").andExpect(status().isOk()));
        UUID appointmentId = UUID.fromString(created.get("id").asText());

        cancelAppointment(token, appointmentId).andExpect(status().isOk());

        Appointment reloaded = appointmentRepository.findById(appointmentId).orElseThrow();
        assertEquals(Appointment.CANCELADO, reloaded.getStatus());
        assertEquals(false, reloaded.ativo());
    }

    @Test
    void cancelamentoLiberaVagaDeCapacidadeCivilParaOutroAluno() throws Exception {
        slot("08:00", 1, false, false); // capacidade 1

        Student a = alunoValido("Civil");
        vinculadoAoUsuario(a, appUserId("aluno"));
        String tokenA = loginAs("aluno");

        JsonNode created = readJson(bookAsStudent(tokenA, amanha(), "08:00").andExpect(status().isOk()));
        UUID appointmentId = UUID.fromString(created.get("id").asText());

        // Segundo aluno (outro usuário) tenta o mesmo slot: cheio.
        UUID userB = newAlunoUser("aluno2-cancel");
        Student b = alunoValido("Civil");
        vinculadoAoUsuario(b, userB);
        String tokenB = loginAs("aluno2-cancel");

        bookAsStudent(tokenB, amanha(), "08:00")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Horário cheio para civis."));

        // Aluno A cancela — libera a vaga.
        cancelAppointment(tokenA, appointmentId).andExpect(status().isOk());

        // Agora o aluno B consegue agendar no mesmo slot.
        bookAsStudent(tokenB, amanha(), "08:00")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(Appointment.AGENDADO));
    }

    @Test
    void alunoNaoPodeCancelarAgendamentoDeOutroAluno() throws Exception {
        Student owner = alunoValido("Civil");
        vinculadoAoUsuario(owner, appUserId("aluno"));
        String ownerToken = loginAs("aluno");
        slotAberto("08:00");

        JsonNode created = readJson(bookAsStudent(ownerToken, amanha(), "08:00").andExpect(status().isOk()));
        UUID appointmentId = UUID.fromString(created.get("id").asText());

        UUID otherUserId = newAlunoUser("aluno2-noown");
        Student other = alunoValido("Civil");
        vinculadoAoUsuario(other, otherUserId);
        String otherToken = loginAs("aluno2-noown");

        cancelAppointment(otherToken, appointmentId)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Você só pode cancelar os seus agendamentos."));

        Appointment reloaded = appointmentRepository.findById(appointmentId).orElseThrow();
        assertEquals(Appointment.AGENDADO, reloaded.getStatus());
    }

    @Test
    void staffPodeCancelarAgendamentoDeQualquerAluno() throws Exception {
        Student s = alunoValido("Civil");
        vinculadoAoUsuario(s, appUserId("aluno"));
        String alunoToken = loginAs("aluno");
        slotAberto("08:00");

        JsonNode created = readJson(bookAsStudent(alunoToken, amanha(), "08:00").andExpect(status().isOk()));
        UUID appointmentId = UUID.fromString(created.get("id").asText());

        String staffToken = loginAs("recepcao");
        cancelAppointment(staffToken, appointmentId).andExpect(status().isOk());

        Appointment reloaded = appointmentRepository.findById(appointmentId).orElseThrow();
        assertEquals(Appointment.CANCELADO, reloaded.getStatus());
    }
}
