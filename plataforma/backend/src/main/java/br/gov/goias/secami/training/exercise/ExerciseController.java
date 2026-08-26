package br.gov.goias.secami.training.exercise;

import br.gov.goias.secami.training.exercise.ExerciseDtos.Response;
import br.gov.goias.secami.training.exercise.ExerciseDtos.UpsertRequest;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** Catálogo de exercícios. Leitura autenticada; escrita admin/professor. SPEC §11.2. */
@RestController
@RequestMapping("/exercises")
public class ExerciseController {

    private final ExerciseRepository repo;

    public ExerciseController(ExerciseRepository repo) {
        this.repo = repo;
    }

    @GetMapping
    public List<Response> list(@RequestParam(value = "q", required = false) String q,
                               @RequestParam(value = "grupo", required = false) String grupo) {
        String term = q == null ? "" : q.trim();
        String g = grupo == null ? "" : grupo.trim();
        return repo.search(term, g).stream().map(Response::from).toList();
    }

    @GetMapping("/{id}")
    public Response get(@PathVariable UUID id) {
        return Response.from(repo.findById(id)
                .orElseThrow(() -> new NotFoundException("Exercício não encontrado.")));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','PROFESSOR')")
    public Response create(@Valid @RequestBody UpsertRequest req) {
        Exercise e = new Exercise();
        apply(e, req);
        return Response.from(repo.save(e));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','PROFESSOR')")
    public Response update(@PathVariable UUID id, @Valid @RequestBody UpsertRequest req) {
        Exercise e = repo.findById(id)
                .orElseThrow(() -> new NotFoundException("Exercício não encontrado."));
        apply(e, req);
        return Response.from(repo.save(e));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','PROFESSOR')")
    public void delete(@PathVariable UUID id) {
        Exercise e = repo.findById(id)
                .orElseThrow(() -> new NotFoundException("Exercício não encontrado."));
        e.setArquivado(true);   // arquiva em vez de excluir (preserva histórico de fichas)
        repo.save(e);
    }

    private void apply(Exercise e, UpsertRequest req) {
        e.setName(req.name());
        e.setMuscleGroup(req.muscleGroup());
        e.setDescription(req.description());
        e.setEquipment(req.equipment());
        e.setPadraoMovimento(req.padraoMovimento());
        e.setVideoUrl(req.videoUrl());
        e.setPhotoId(req.photoId());
        if (req.arquivado() != null) e.setArquivado(req.arquivado());
    }
}
