package br.gov.goias.secami.training.coaching;

import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.training.coaching.CoachDtos.*;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Endpoints de coaching. SPEC §9.3. */
@RestController
@RequestMapping("/coach")
public class CoachController {

    private final CoachService service;
    private final CurrentUser currentUser;

    public CoachController(CoachService service, CurrentUser currentUser) {
        this.service = service;
        this.currentUser = currentUser;
    }

    @PostMapping("/invites")
    @PreAuthorize("hasAnyRole('PROFESSOR','ADMIN')")
    public ConviteResponse criarConvite(@RequestBody(required = false) CriarConviteRequest req) {
        CriarConviteRequest r = req != null ? req : new CriarConviteRequest(null, null, null, null);
        return ConviteResponse.from(service.criarConvite(
                currentUser.id(), r.tipo(), r.orgId(), r.usosMax(), r.validadeDias()));
    }

    @PostMapping("/invites/redeem")
    public void resgatar(@Valid @RequestBody ResgatarRequest req) {
        service.resgatar(req.codigo(), currentUser.id());
    }

    @GetMapping("/students")
    @PreAuthorize("hasAnyRole('PROFESSOR','ADMIN')")
    public List<VinculoAlunoResponse> meusAlunos() {
        return service.meusAlunos(currentUser.id());
    }

    @GetMapping("/trainers")
    public List<VinculoTreinadorResponse> meusTreinadores() {
        return service.meusTreinadores(currentUser.id());
    }
}
