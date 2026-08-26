package br.gov.goias.secami.academy.appointment;

import br.gov.goias.secami.academy.appointment.AppointmentDtos.*;
import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.identity.Roles;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

@RestController
public class AppointmentController {

    private final SchedulingService scheduling;
    private final CurrentUser currentUser;

    public AppointmentController(SchedulingService scheduling, CurrentUser currentUser) {
        this.scheduling = scheduling;
        this.currentUser = currentUser;
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
    public List<Response> list(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        return scheduling.byRange(from, to).stream().map(Response::from).toList();
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

    // ---- Cancelar (staff ou dono) ----

    @DeleteMapping("/appointments/{id}")
    public void cancel(@PathVariable UUID id) {
        boolean staff = currentUser.hasRole(Roles.ADMIN)
                || currentUser.hasRole(Roles.GERENTE)
                || currentUser.hasRole(Roles.RECEPCAO);
        scheduling.cancel(id, currentUser.id(), staff);
    }
}
