package br.gov.goias.secami.jobs;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/** Gatilhos manuais dos jobs (admin), úteis para operação e testes. */
@RestController
@RequestMapping("/admin/jobs")
@PreAuthorize("hasRole('ADMIN')")
public class JobsController {

    private final AbsenceService absenceService;
    private final ReminderService reminderService;

    public JobsController(AbsenceService absenceService, ReminderService reminderService) {
        this.absenceService = absenceService;
        this.reminderService = reminderService;
    }

    @PostMapping("/mark-absences")
    public Map<String, Object> markAbsences() {
        int n = absenceService.markAbsences();
        return Map.of("marcados", n);
    }

    @PostMapping("/send-reminders")
    public Map<String, Object> sendReminders() {
        int n = reminderService.sendReminders();
        return Map.of("enviados", n);
    }
}
