package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import org.junit.jupiter.api.Test;

import java.time.ZonedDateTime;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * SPEC §9.5 — marcação automática de falta (job {@code AbsenceService}, disparado
 * manualmente via POST /admin/jobs/mark-absences): agendamento passado sem check-in
 * vira falta; agendamento de hoje com 60min+ de atraso sem check-in também vira
 * falta; abaixo do limiar, ou já com check-in registrado, permanece 'agendado'.
 */
class AbsenceJobTest extends SchedulingTestSupport {

    private String timeMinutesAgo(int minutes) {
        return ZonedDateTime.now(zone()).minusMinutes(minutes).format(HHMM);
    }

    private void runJob(String adminToken) throws Exception {
        mockMvc.perform(authed(post("/admin/jobs/mark-absences"), adminToken)).andExpect(status().isOk());
    }

    @Test
    void agendamentoDeDataPassadaSemCheckIn_viraFalta() throws Exception {
        Student s = civil();
        Appointment appt = seedAppointment(s, ontem(), "08:00", Appointment.AGENDADO);

        runJob(loginAs("admin"));

        assertEquals(Appointment.FALTOU, appointmentRepository.findById(appt.getId()).orElseThrow().getStatus());
    }

    @Test
    void agendamentoDeHojeComMaisDe60MinDeAtrasoSemCheckIn_viraFalta() throws Exception {
        Student s = civil();
        Appointment appt = seedAppointment(s, hoje(), timeMinutesAgo(90), Appointment.AGENDADO);

        runJob(loginAs("admin"));

        assertEquals(Appointment.FALTOU, appointmentRepository.findById(appt.getId()).orElseThrow().getStatus());
    }

    @Test
    void agendamentoDeHojeComMenosDe60MinDeAtraso_naoEMarcadoAinda() throws Exception {
        Student s = civil();
        Appointment appt = seedAppointment(s, hoje(), timeMinutesAgo(10), Appointment.AGENDADO);

        runJob(loginAs("admin"));

        assertEquals(Appointment.AGENDADO, appointmentRepository.findById(appt.getId()).orElseThrow().getStatus());
    }

    @Test
    void agendamentoComCheckInRegistrado_naoEMarcadoMesmoComAtraso() throws Exception {
        Student s = civil();
        Appointment appt = seedAppointment(s, hoje(), timeMinutesAgo(120), Appointment.AGENDADO);
        seedCheckIn(s, hoje(), appt.getId()); // "compareceu"

        runJob(loginAs("admin"));

        assertEquals(Appointment.AGENDADO, appointmentRepository.findById(appt.getId()).orElseThrow().getStatus());
    }
}
