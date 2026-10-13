package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.checkin.CheckInService;
import br.gov.goias.secami.accelero.AcceleroSyncService;
import br.gov.goias.secami.config.SecamiProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

/**
 * Confere no Accelero (log de eventos reais da catraca) se os alunos com
 * agendamento hoje/ontem realmente entraram e/ou saíram da academia, além
 * do check-in autodeclarado — permite ver quem faltou de verdade e calcular
 * permanência real (ver AcceleroSyncService.confirmarPresenca). Entrada
 * confirmada conta como presença no dia (CheckInService.registrarPresencaPelaCatraca).
 */
@Service
public class AcceleroPresencaService {

    private static final Logger log = LoggerFactory.getLogger(AcceleroPresencaService.class);

    private final AppointmentRepository appointments;
    private final AcceleroSyncService acceleroSync;
    private final CheckInService checkIns;
    private final ZoneId zone;

    public AcceleroPresencaService(AppointmentRepository appointments, AcceleroSyncService acceleroSync,
                                    CheckInService checkIns, SecamiProperties props) {
        this.appointments = appointments;
        this.acceleroSync = acceleroSync;
        this.checkIns = checkIns;
        this.zone = ZoneId.of(props.getTimezone());
    }

    /** Roda a cada 30 min. */
    @Scheduled(cron = "0 */30 * * * *", zone = "America/Sao_Paulo")
    public void agendado() {
        int n = confirmarPresencas();
        if (n > 0) log.info("confirmarPresencas: {} agendamento(s) com entrada/saída confirmada", n);
    }

    @Transactional
    public int confirmarPresencas() {
        LocalDate hoje = LocalDate.now(zone);
        List<Appointment> candidatos = appointments.findCandidatosConfirmacaoPresenca(
                List.of(hoje.minusDays(1), hoje));
        int count = 0;
        for (Appointment a : candidatos) {
            boolean confirmou = acceleroSync.confirmarPresenca(a);
            boolean presenca = checkIns.registrarPresencaPelaCatraca(a);
            if (confirmou || presenca) count++;
        }
        return count;
    }
}
