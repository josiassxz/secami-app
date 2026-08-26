package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.checkin.CheckInRepository;
import br.gov.goias.secami.config.SecamiProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.UUID;

/**
 * Marcação automática de falta (SPEC §9.5). Varre agendamentos 'agendado':
 * - data passada sem check-in → faltou;
 * - hoje, se passaram 60 min do slot_start sem check-in → faltou.
 */
@Service
public class AbsenceService {

    private static final Logger log = LoggerFactory.getLogger(AbsenceService.class);
    private static final int LIMIAR_MINUTOS = 60;

    private final AppointmentRepository appointments;
    private final CheckInRepository checkins;
    private final ZoneId zone;

    public AbsenceService(AppointmentRepository appointments, CheckInRepository checkins,
                          SecamiProperties props) {
        this.appointments = appointments;
        this.checkins = checkins;
        this.zone = ZoneId.of(props.getTimezone());
    }

    /** Roda a cada 15 min (fuso America/Sao_Paulo). */
    @Scheduled(cron = "0 */15 * * * *", zone = "America/Sao_Paulo")
    public void agendado() {
        int n = markAbsences();
        if (n > 0) log.info("markAbsences: {} agendamento(s) marcados como falta", n);
    }

    @Transactional
    public int markAbsences() {
        ZonedDateTime now = ZonedDateTime.now(zone);
        LocalDate hoje = now.toLocalDate();
        int count = 0;
        for (Appointment a : appointments.findAgendadosAte(hoje)) {
            UUID studentId = a.getStudent().getId();
            LocalDate date = a.getDate();
            if (checkins.existsByStudentIdAndDate(studentId, date)) {
                continue; // compareceu
            }
            boolean marcar;
            if (date.isBefore(hoje)) {
                marcar = true;
            } else {
                long min = Duration.between(
                        ZonedDateTime.of(date, LocalTime.parse(a.getSlotStart()), zone), now).toMinutes();
                marcar = min >= LIMIAR_MINUTOS;
            }
            if (marcar) {
                a.setStatus(Appointment.FALTOU);
                appointments.save(a);
                count++;
            }
        }
        return count;
    }
}
