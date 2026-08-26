package br.gov.goias.secami.academy.notice;

import br.gov.goias.secami.academy.notice.NoticeDtos.Response;
import br.gov.goias.secami.academy.notice.NoticeDtos.UpsertRequest;
import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** Avisos/informativos. Leitura filtra por papel; escrita admin/gerente. SPEC §11.2. */
@RestController
@RequestMapping("/notices")
public class NoticeController {

    private final NoticeRepository repo;
    private final CurrentUser currentUser;

    public NoticeController(NoticeRepository repo, CurrentUser currentUser) {
        this.repo = repo;
        this.currentUser = currentUser;
    }

    /** Todos (para gestão). Admin/gerente. */
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public List<Response> listAll() {
        return repo.findAll().stream().map(Response::from).toList();
    }

    /** Ativos visíveis para os papéis do usuário atual (dashboard). */
    @GetMapping("/active")
    public List<Response> activeForMe() {
        var roles = currentUser.require().getRoles();
        return repo.findByActiveTrueOrderByCreatedAtDesc().stream()
                .filter(n -> n.getTargetRoles() == null || n.getTargetRoles().isEmpty()
                        || n.getTargetRoles().stream().anyMatch(roles::contains))
                .map(Response::from)
                .toList();
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Response create(@Valid @RequestBody UpsertRequest req) {
        Notice n = new Notice();
        apply(n, req);
        n.setCreatedBy(currentUser.id());
        return Response.from(repo.save(n));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Response update(@PathVariable UUID id, @Valid @RequestBody UpsertRequest req) {
        Notice n = repo.findById(id)
                .orElseThrow(() -> new NotFoundException("Aviso não encontrado."));
        apply(n, req);
        return Response.from(repo.save(n));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public void delete(@PathVariable UUID id) {
        repo.deleteById(id);
    }

    private void apply(Notice n, UpsertRequest req) {
        n.setTitle(req.title());
        n.setContent(req.content());
        if (req.type() != null) n.setType(req.type());
        if (req.active() != null) n.setActive(req.active());
        if (req.targetRoles() != null) n.setTargetRoles(req.targetRoles());
    }
}
