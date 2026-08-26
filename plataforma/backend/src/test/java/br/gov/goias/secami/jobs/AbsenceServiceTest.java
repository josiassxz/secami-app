package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * {@link AbsenceService#markAbsences()} (SPEC §9.5): varre agendamentos
 * 'agendado' e marca falta quando (a) a data já passou sem check-in, ou (b)
 * é hoje e já passaram 60min do horário sem check-in. Dentro dos 60min, ou
 * com check-in registrado, o agendamento não é tocado.
 */
class AbsenceServiceTest extends JobsTestSupport {

    private static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");

    @Autowired private AbsenceService absenceService;

    @Test
    void agendamentoDeDataPassadaSemCheckinViraFaltou() {
        Student aluno = createStudent("passado", "aluno.passado@teste.com");
        Appointment ap = createAppointment(aluno, LocalDate.now(ZONE).minusDays(2),
                LocalTime.of(8, 0), Appointment.AGENDADO);

        int marcados = absenceService.markAbsences();

        assertThat(marcados).isGreaterThanOrEqualTo(1);
        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.getStatus()).isEqualTo(Appointment.FALTOU);
    }

    @Test
    void agendamentoDeHojeComMaisDe60MinDeAtrasoSemCheckinViraFaltou() {
        Student aluno = createStudent("atrasado", "aluno.atrasado@teste.com");
        // Deriva data/hora do mesmo instante deslocado (evita drift de virada de dia).
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).minusMinutes(90);
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);

        int marcados = absenceService.markAbsences();

        assertThat(marcados).isGreaterThanOrEqualTo(1);
        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.getStatus()).isEqualTo(Appointment.FALTOU);
    }

    @Test
    void agendamentoDeHojeDentroDe60MinContinuaAgendado() {
        Student aluno = createStudent("recente", "aluno.recente@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).minusMinutes(20);
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);

        absenceService.markAbsences();

        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.getStatus()).isEqualTo(Appointment.AGENDADO);
    }

    @Test
    void agendamentoFuturoDeHojeContinuaAgendado() {
        Student aluno = createStudent("futuro", "aluno.futuro@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).plusMinutes(30);
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);

        absenceService.markAbsences();

        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.getStatus()).isEqualTo(Appointment.AGENDADO);
    }

    @Test
    void agendamentoComCheckinNaoViraFaltouMesmoMuitoAtrasado() {
        Student aluno = createStudent("compareceu", "aluno.compareceu@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).minusMinutes(180);
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);
        createCheckIn(aluno, ap.getDate(), alvo.toLocalTime());

        absenceService.markAbsences();

        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.getStatus()).isEqualTo(Appointment.AGENDADO);
    }

    @Test
    void agendamentoJaCanceladoNaoEhAfetado() {
        Student aluno = createStudent("cancelado", "aluno.cancelado@teste.com");
        Appointment ap = createAppointment(aluno, LocalDate.now(ZONE).minusDays(3),
                LocalTime.of(9, 0), Appointment.CANCELADO);

        absenceService.markAbsences();

        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.getStatus()).isEqualTo(Appointment.CANCELADO);
    }
}
