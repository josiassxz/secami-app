package br.gov.goias.secami.academy.student;

import br.gov.goias.secami.academy.student.StudentDtos.MeUpdateRequest;
import br.gov.goias.secami.academy.student.StudentDtos.Response;
import br.gov.goias.secami.academy.student.StudentDtos.UpsertRequest;
import br.gov.goias.secami.auth.CurrentUser;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/** Gestão de alunos. RBAC conforme SPEC §11.1. */
@RestController
public class StudentController {

    private final StudentService service;
    private final CurrentUser currentUser;

    public StudentController(StudentService service, CurrentUser currentUser) {
        this.service = service;
        this.currentUser = currentUser;
    }

    @GetMapping("/students")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO','PROFESSOR')")
    public Page<Response> list(@RequestParam(value = "q", required = false) String q,
                               @RequestParam(value = "page", defaultValue = "0") int page,
                               @RequestParam(value = "size", defaultValue = "20") int size) {
        // Listagem mascara o CPF (LGPD §14).
        return service.search(q, PageRequest.of(page, Math.min(size, 100)))
                .map(s -> Response.from(s, true));
    }

    @GetMapping("/students/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO','PROFESSOR')")
    public Response get(@PathVariable UUID id) {
        return Response.from(service.get(id), false);
    }

    @PostMapping("/students")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Response create(@Valid @RequestBody UpsertRequest req) {
        return Response.from(service.create(req), false);
    }

    @PutMapping("/students/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Response update(@PathVariable UUID id, @Valid @RequestBody UpsertRequest req) {
        return Response.from(service.update(id, req), false);
    }

    @DeleteMapping("/students/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public void delete(@PathVariable UUID id) {
        service.delete(id);
    }

    // ---- Aluno: próprio perfil ----

    @GetMapping("/me/student")
    public Response myProfile() {
        return Response.from(service.requireByUser(currentUser.id()), false);
    }

    @PutMapping("/me/student")
    public Response updateMyProfile(@Valid @RequestBody MeUpdateRequest req) {
        return Response.from(service.updateOwnProfile(currentUser.id(), req), false);
    }
}
