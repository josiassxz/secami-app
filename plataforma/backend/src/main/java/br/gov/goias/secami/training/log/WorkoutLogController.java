package br.gov.goias.secami.training.log;

import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.training.log.WorkoutLogDtos.Response;
import br.gov.goias.secami.training.log.WorkoutLogDtos.UpsertRequest;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;

@RestController
@RequestMapping("/me/workout-logs")
public class WorkoutLogController {

    private final WorkoutLogService service;
    private final CurrentUser currentUser;

    public WorkoutLogController(WorkoutLogService service, CurrentUser currentUser) {
        this.service = service;
        this.currentUser = currentUser;
    }

    @GetMapping("/today")
    public Response today(@RequestParam(required = false)
                          @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        LocalDate d = date != null ? date : LocalDate.now();
        return service.today(currentUser.id(), d).map(Response::from).orElse(null);
    }

    @GetMapping
    public List<Response> history() {
        return service.history(currentUser.id()).stream().map(Response::from).toList();
    }

    @PutMapping
    public Response upsert(@Valid @RequestBody UpsertRequest req) {
        return Response.from(service.upsert(currentUser.id(), req));
    }
}
