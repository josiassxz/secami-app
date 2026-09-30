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
    private final StudentEmailService emails;

    public StudentController(StudentService service, CurrentUser currentUser, StudentEmailService emails) {
        this.service = service;
        this.currentUser = currentUser;
        this.emails = emails;
    }

    @GetMapping("/students")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO','PROFESSOR')")
    public Page<Response> list(@RequestParam(value = "q", required = false) String q,
                               @RequestParam(value = "perfil", required = false) String perfil,
                               @RequestParam(value = "page", defaultValue = "0") int page,
                               @RequestParam(value = "size", defaultValue = "20") int size) {
        // Listagem mascara o CPF (LGPD §14).
        return service.search(q, perfil, PageRequest.of(page, Math.min(size, 100)))
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

    @PatchMapping("/students/{id}/situacao")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Response updateSituacao(@PathVariable UUID id, @RequestParam String situacao) {
        return Response.from(service.updateSituacao(id, situacao), false);
    }

    @DeleteMapping("/students/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public void delete(@PathVariable UUID id) {
        service.delete(id);
    }

    /**
     * Atualiza em lote o e-mail de contato dos alunos a partir de uma lista
     * (CPF, e-mail) — ver {@link StudentEmailService}. {@code simular=true}
     * (padrão) só conta o que faria, sem gravar.
     */
    @PostMapping("/admin/alunos/atualizar-emails")
    @PreAuthorize("hasRole('ADMIN')")
    public StudentEmailService.Resultado atualizarEmails(
            @RequestBody java.util.List<StudentEmailService.Item> itens,
            @RequestParam(defaultValue = "true") boolean simular) {
        return emails.atualizarPorCpf(itens, simular);
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
