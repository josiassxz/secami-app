package br.gov.goias.secami.academy.appointment;

import br.gov.goias.secami.academy.appointment.AppointmentDtos.*;
import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.identity.Roles;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import jakarta.servlet.http.HttpServletResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;

import java.io.IOException;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
public class AppointmentController {

    private final SchedulingService scheduling;
    private final CurrentUser currentUser;
    private final RelatorioExportService relatorioExportService;

    public AppointmentController(SchedulingService scheduling, CurrentUser currentUser, RelatorioExportService relatorioExportService) {
        this.scheduling = scheduling;
        this.currentUser = currentUser;
        this.relatorioExportService = relatorioExportService;
    }

    // ---- Aluno ----

    @GetMapping("/me/appointments/available")
    public List<AvailableSlot> available(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return scheduling.availableSlots(currentUser.id(), date);
    }

    @PostMapping("/me/appointments")
    public Response book(@Valid @RequestBody StudentBookRequest req) {
        return Response.from(scheduling.bookAsStudent(currentUser.id(), req.date(), req.slotStart()));
    }

    @GetMapping("/me/appointments")
    public List<Response> myAppointments() {
        return scheduling.myAppointments(currentUser.id()).stream().map(Response::from).toList();
    }

    // ---- Staff ----

    @GetMapping("/appointments")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO','PROFESSOR')")
    public Page<Response> list(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size) {
        return scheduling.byRangeFiltered(from, to, status, q,
                PageRequest.of(page, Math.min(size, 200))).map(Response::from);
    }

    @GetMapping("/appointments/summary")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO','PROFESSOR')")
    public SummaryResponse summary(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String q) {
        return scheduling.summarize(from, to, status, q);
    }

    @GetMapping("/appointments/export")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public void exportExcel(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String q,
            HttpServletResponse response) throws IOException {
        response.setContentType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
        response.setHeader("Content-Disposition",
                "attachment; filename=relatorio_" + from + "_" + to + ".xlsx");
        relatorioExportService.exportar(from, to, status, q, response.getOutputStream());
    }

    @GetMapping("/schedule")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO','PROFESSOR')")
    public List<ScheduleSlot> schedule(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return scheduling.schedule(date);
    }

    @PostMapping("/appointments")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO')")
    public Response forceBook(@Valid @RequestBody StaffBookRequest req) {
        return Response.from(scheduling.forceBook(
                req.studentId(), req.date(), req.slotStart(), req.notes(), currentUser.id()));
    }

    // ---- Histórico do aluno (staff) ----

    @GetMapping("/students/{studentId}/appointments")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO')")
    public List<Response> studentHistory(
            @PathVariable UUID studentId,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return scheduling.getStudentHistory(studentId, from, to).stream().map(Response::from).toList();
    }

    // ---- Cancelar (staff ou dono) ----

    @DeleteMapping("/appointments/{id}")
    public void cancel(@PathVariable UUID id) {
        boolean staff = currentUser.hasRole(Roles.ADMIN)
                || currentUser.hasRole(Roles.GERENTE)
                || currentUser.hasRole(Roles.RECEPCAO);
        scheduling.cancel(id, currentUser.id(), staff);
    }
}
