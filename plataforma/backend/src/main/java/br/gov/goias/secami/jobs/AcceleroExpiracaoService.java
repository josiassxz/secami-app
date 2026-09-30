package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.accelero.AcceleroSyncService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;

/**
 * Remove do Accelero o acesso dinâmico liberado pro civil a cada agendamento
 * (ver AcceleroSyncService), depois que a janela (20min antes até 5h depois
 * do início) expira — mesmo sem cancelamento, já que a maioria dos
 * agendamentos simplesmente acontece e passa. Sem isso o vínculo fica
 * esquecido no Accelero indefinidamente.
 */
@Service
public class AcceleroExpiracaoService {

    private static final Logger log = LoggerFactory.getLogger(AcceleroExpiracaoService.class);

    private final AppointmentRepository appointments;
    private final AcceleroSyncService acceleroSync;

    public AcceleroExpiracaoService(AppointmentRepository appointments, AcceleroSyncService acceleroSync) {
        this.appointments = appointments;
        this.acceleroSync = acceleroSync;
    }

    /** Roda a cada 15 min. */
    @Scheduled(cron = "0 */15 * * * *", zone = "America/Sao_Paulo")
    public void agendado() {
        int n = removerAcessosExpirados();
        if (n > 0) log.info("removerAcessosExpirados: {} acesso(s) removido(s) do Accelero", n);
    }

    @Transactional
    public int removerAcessosExpirados() {
        int count = 0;
        for (Appointment a : appointments.findComAcessoAcceleroExpirado(OffsetDateTime.now())) {
            acceleroSync.aoExpirarAcesso(a);
            count++;
        }
        return count;
    }
}
