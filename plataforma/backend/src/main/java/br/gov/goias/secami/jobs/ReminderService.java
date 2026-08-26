package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.config.SecamiProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Lembrete de agendamento por e-mail (SPEC §9.6, legado: sendAppointmentReminders).
 * A cada 5 min, avisa alunos cujo horário começa entre 57 e 62 minutos —
 * mesma janela do sistema legado. A janela (5min) é mais larga que o
 * intervalo entre execuções do cron, então o mesmo agendamento pode cair
 * dentro dela em mais de um tick — {@code lembrete_enviado} evita reenviar.
 */
@Service
public class ReminderService {

    private static final Logger log = LoggerFactory.getLogger(ReminderService.class);
    private static final long JANELA_MIN_MINUTOS = 57;
    private static final long JANELA_MAX_MINUTOS = 62;

    private final AppointmentRepository appointments;
    private final JavaMailSender mailSender;
    private final ZoneId zone;

    public ReminderService(AppointmentRepository appointments, JavaMailSender mailSender,
                           SecamiProperties props) {
        this.appointments = appointments;
        this.mailSender = mailSender;
        this.zone = ZoneId.of(props.getTimezone());
    }

    @Scheduled(cron = "0 */5 * * * *", zone = "America/Sao_Paulo")
    public void agendado() {
        int n = sendReminders();
        if (n > 0) log.info("sendAppointmentReminders: {} e-mail(s) enviado(s)", n);
    }

    @Transactional
    public int sendReminders() {
        ZonedDateTime now = ZonedDateTime.now(zone);
        LocalDate hoje = now.toLocalDate();
        List<Appointment> doDia = appointments.findByDateAndDeletedAtIsNull(hoje);

        Set<String> statusAlvo = new HashSet<>(Set.of(Appointment.AGENDADO, Appointment.CONFIRMADO));
        int enviados = 0;
        for (Appointment a : doDia) {
            if (a.isLembreteEnviado() || !statusAlvo.contains(a.getStatus())) continue;
            ZonedDateTime inicio = ZonedDateTime.of(hoje, LocalTime.parse(a.getSlotStart()), zone);
            long minutos = Duration.between(now, inicio).toMinutes();
            if (minutos < JANELA_MIN_MINUTOS || minutos > JANELA_MAX_MINUTOS) continue;

            String email = a.getStudent().getEmail();
            if (email == null || email.isBlank()) continue;

            enviarEmail(email, a.getStudent().getFullName(), a.getSlotStart());
            a.setLembreteEnviado(true);
            appointments.save(a);
            enviados++;
        }
        return enviados;
    }

    private void enviarEmail(String destinatario, String nomeAluno, String horario) {
        try {
            SimpleMailMessage msg = new SimpleMailMessage();
            msg.setTo(destinatario);
            msg.setSubject("Seu treino começa em 1 hora");
            msg.setText("""
                    Olá, %s!

                    Seu treino na Academia da Casa Militar está agendado para hoje às %s.

                    Não esqueça de trazer sua identificação para o check-in.

                    Academia SECAMI — Casa Militar de Goiás
                    """.formatted(nomeAluno, horario));
            mailSender.send(msg);
        } catch (Exception e) {
            log.warn("Falha ao enviar lembrete para {}: {}", destinatario, e.getMessage());
        }
    }
}
