package br.gov.goias.secami.academy.department;

import br.gov.goias.secami.academy.department.DepartmentDtos.Response;
import br.gov.goias.secami.academy.department.DepartmentDtos.UpsertRequest;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** CRUD de secretarias/órgãos. Leitura autenticada; escrita admin/gerente. SPEC §11.1. */
@RestController
@RequestMapping("/departments")
public class DepartmentController {

    private final DepartmentRepository repo;

    public DepartmentController(DepartmentRepository repo) {
        this.repo = repo;
    }

    @GetMapping
    public List<Response> list() {
        return repo.findAll().stream().map(Response::from).toList();
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Response create(@Valid @RequestBody UpsertRequest req) {
        Department d = new Department();
        apply(d, req);
        return Response.from(repo.save(d));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Response update(@PathVariable UUID id, @Valid @RequestBody UpsertRequest req) {
        Department d = repo.findById(id)
                .orElseThrow(() -> new NotFoundException("Secretaria não encontrada."));
        apply(d, req);
        return Response.from(repo.save(d));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public void delete(@PathVariable UUID id) {
        repo.deleteById(id);
    }

    private void apply(Department d, UpsertRequest req) {
        d.setName(req.name());
        d.setSigla(req.sigla());
        d.setAndar(req.andar());
        if (req.active() != null) d.setActive(req.active());
    }
}
