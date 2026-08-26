package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;

import java.time.ZoneId;
import java.time.ZonedDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

/**
 * {@link ReminderService#sendReminders()} (SPEC §9.6): avisa por e-mail
 * agendamentos cujo horário começa entre 57 e 62 minutos a partir de agora.
 * {@code lembrete_enviado} evita duplicidade — a janela do cron (5min) é mais
 * estreita que a janela de disparo (5min também, mas desalinhada), então o
 * mesmo agendamento pode ser reavaliado em mais de um tick.
 *
 * <p>Usa {@code @MockBean} em {@link JavaMailSender} — não depende de
 * Mailpit/Docker rodando; verifica via Mockito que {@code send(...)} foi (ou
 * não foi) chamado, sem enviar e-mail de verdade.
 */
class ReminderServiceTest extends JobsTestSupport {

    private static final ZoneId ZONE = ZoneId.of("America/Sao_Paulo");

    @Autowired private ReminderService reminderService;
    @MockBean private JavaMailSender mailSender;

    @Test
    void dentroDaJanela57a62MinutosDisparaEmail() {
        Student aluno = createStudent("janela", "aluno.janela@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).plusMinutes(60); // meio da janela [57,62]
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);

        int enviados = reminderService.sendReminders();

        assertThat(enviados).isEqualTo(1);
        ArgumentCaptor<SimpleMailMessage> captor = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mailSender, times(1)).send(captor.capture());
        SimpleMailMessage msg = captor.getValue();
        assertThat(msg.getTo()).containsExactly("aluno.janela@teste.com");
        assertThat(msg.getSubject()).contains("1 hora");
        assertThat(msg.getText()).contains(aluno.getFullName());
        assertThat(msg.getText()).contains(ap.getSlotStart());

        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.isLembreteEnviado()).isTrue();
    }

    @Test
    void foraDaJanelaMuitoCedoNaoDisparaEmail() {
        Student aluno = createStudent("cedo", "aluno.cedo@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).plusMinutes(150); // bem além dos 62min
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);

        int enviados = reminderService.sendReminders();

        assertThat(enviados).isEqualTo(0);
        verifyNoInteractions(mailSender);
        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.isLembreteEnviado()).isFalse();
    }

    @Test
    void foraDaJanelaMuitoPertoNaoDisparaEmail() {
        Student aluno = createStudent("perto", "aluno.perto@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).plusMinutes(20); // bem antes dos 57min
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);

        int enviados = reminderService.sendReminders();

        assertThat(enviados).isEqualTo(0);
        verifyNoInteractions(mailSender);
        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.isLembreteEnviado()).isFalse();
    }

    @Test
    void jaComLembreteEnviadoNaoDisparaDeNovoMesmoDentroDaJanela() {
        Student aluno = createStudent("jaenviado", "aluno.jaenviado@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).plusMinutes(60);
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(),
                Appointment.AGENDADO, true);

        int enviados = reminderService.sendReminders();

        assertThat(enviados).isEqualTo(0);
        verifyNoInteractions(mailSender);
        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.isLembreteEnviado()).isTrue();
    }

    /**
     * Regressão do bug real corrigido nesta sessão: rodar o job duas vezes
     * seguidas (mesma janela) não pode reenviar o e-mail — a segunda chamada
     * já deve ver {@code lembrete_enviado=true} setado pela primeira.
     */
    @Test
    void executarDuasVezesSeguidasNaoEnviaEmailDuplicado() {
        Student aluno = createStudent("duaschamadas", "aluno.duaschamadas@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).plusMinutes(60);
        Appointment ap = createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);

        int primeiraChamada = reminderService.sendReminders();
        int segundaChamada = reminderService.sendReminders();

        assertThat(primeiraChamada).isEqualTo(1);
        assertThat(segundaChamada).isEqualTo(0);
        verify(mailSender, times(1)).send(any(SimpleMailMessage.class));
        Appointment reloaded = appointmentRepository.findById(ap.getId()).orElseThrow();
        assertThat(reloaded.isLembreteEnviado()).isTrue();
    }

    @Test
    void statusCanceladoDentroDaJanelaNaoRecebeLembrete() {
        Student aluno = createStudent("cancelado", "aluno.cancelado@teste.com");
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).plusMinutes(60);
        createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.CANCELADO);

        int enviados = reminderService.sendReminders();

        assertThat(enviados).isEqualTo(0);
        verify(mailSender, never()).send(any(SimpleMailMessage.class));
    }

    @Test
    void alunoSemEmailNaoDisparaNemQuebraOJob() {
        Student aluno = createStudent("sememail", null);
        ZonedDateTime alvo = ZonedDateTime.now(ZONE).plusMinutes(60);
        createAppointment(aluno, alvo.toLocalDate(), alvo.toLocalTime(), Appointment.AGENDADO);

        int enviados = reminderService.sendReminders();

        assertThat(enviados).isEqualTo(0);
        verifyNoInteractions(mailSender);
    }
}
