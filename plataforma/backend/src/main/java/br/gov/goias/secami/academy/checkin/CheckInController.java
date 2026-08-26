package br.gov.goias.secami.academy.checkin;

import br.gov.goias.secami.academy.checkin.CheckInDtos.CheckInRequest;
import br.gov.goias.secami.academy.checkin.CheckInDtos.Response;
import br.gov.goias.secami.auth.CurrentUser;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/** Console de presença da recepção. Acesso: admin/recepcao/professor. SPEC §11.1. */
@RestController
@PreAuthorize("hasAnyRole('ADMIN','RECEPCAO','PROFESSOR')")
public class CheckInController {

    private final CheckInService service;
    private final CurrentUser currentUser;

    public CheckInController(CheckInService service, CurrentUser currentUser) {
        this.service = service;
        this.currentUser = currentUser;
    }

    @GetMapping("/checkins")
    public List<Response> byDate(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return service.byDate(date).stream().map(Response::from).toList();
    }

    @PostMapping("/checkins")
    public Response checkIn(@Valid @RequestBody CheckInRequest req) {
        return Response.from(service.checkIn(req.studentId(), req.date(), req.notes(), currentUser.id()));
    }

    @PatchMapping("/checkins/{id}/checkout")
    public Response checkOut(@PathVariable UUID id) {
        return Response.from(service.checkOut(id));
    }

    @DeleteMapping("/checkins/{id}")
    public void undo(@PathVariable UUID id) {
        service.undo(id);
    }

    @PatchMapping("/appointments/{id}/falta")
    public void marcarFalta(@PathVariable UUID id) {
        service.marcarFalta(id);
    }

    @PatchMapping("/appointments/{id}/desfazer-falta")
    public void desfazerFalta(@PathVariable UUID id) {
        service.desfazerFalta(id);
    }
}
