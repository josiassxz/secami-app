package br.gov.goias.secami.training.plan;

import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.training.plan.WorkoutPlanDtos.Response;
import br.gov.goias.secami.training.plan.WorkoutPlanDtos.UpsertRequest;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** Fichas de treino. Escrita professor/admin; aluno lê as próprias. SPEC §11.2. */
@RestController
public class WorkoutPlanController {

    private final WorkoutPlanService service;
    private final CurrentUser currentUser;

    public WorkoutPlanController(WorkoutPlanService service, CurrentUser currentUser) {
        this.service = service;
        this.currentUser = currentUser;
    }

    @GetMapping("/students/{studentId}/workout-plans")
    @PreAuthorize("hasAnyRole('ADMIN','PROFESSOR')")
    public List<Response> byStudent(@PathVariable UUID studentId) {
        return service.byStudent(studentId).stream().map(Response::from).toList();
    }

    @PostMapping("/workout-plans")
    @PreAuthorize("hasAnyRole('ADMIN','PROFESSOR')")
    public Response create(@Valid @RequestBody UpsertRequest req) {
        return Response.from(service.create(req, currentUser.id()));
    }

    @PutMapping("/workout-plans/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','PROFESSOR')")
    public Response update(@PathVariable UUID id, @Valid @RequestBody UpsertRequest req) {
        return Response.from(service.update(id, req));
    }

    @DeleteMapping("/workout-plans/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','PROFESSOR')")
    public void delete(@PathVariable UUID id) {
        service.delete(id);
    }

    @GetMapping("/me/workout-plans")
    public List<Response> myPlans() {
        return service.myPlans(currentUser.id()).stream().map(Response::from).toList();
    }
}
