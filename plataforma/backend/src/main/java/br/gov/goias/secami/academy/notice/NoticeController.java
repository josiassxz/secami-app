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
    private final NoticeDispensaRepository dispensas;
    private final CurrentUser currentUser;
    private final java.time.ZoneId zone;

    public NoticeController(NoticeRepository repo, NoticeDispensaRepository dispensas, CurrentUser currentUser,
                            br.gov.goias.secami.config.SecamiProperties props) {
        this.repo = repo;
        this.dispensas = dispensas;
        this.currentUser = currentUser;
        this.zone = java.time.ZoneId.of(props.getTimezone());
    }

    private java.time.LocalDate hoje() {
        return java.time.LocalDate.now(zone);
    }

    /** Todos (para gestão). Admin/gerente. */
    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public List<Response> listAll() {
        return repo.findAll().stream().map(Response::from).toList();
    }

    /** Ativos, dentro do período de exibição e visíveis para os papéis do
     *  usuário atual (tela "Avisos" do app e painel do admin). */
    @GetMapping("/active")
    public List<Response> activeForMe() {
        var roles = currentUser.require().getRoles();
        java.time.LocalDate hoje = hoje();
        return repo.findByActiveTrueOrderByCreatedAtDesc().stream()
                .filter(n -> n.emExibicao(hoje) && n.visivelPara(roles))
                .map(Response::from)
                .toList();
    }

    /** O que o app deve abrir como janela ao entrar: os avisos de
     *  {@link #activeForMe()} menos os que o usuário marcou "não mostrar novamente". */
    @GetMapping("/modal")
    public List<Response> modalForMe() {
        var dispensados = dispensas.avisosDispensadosPor(currentUser.id());
        return activeForMe().stream().filter(n -> !dispensados.contains(n.id())).toList();
    }

    /** "Não mostrar novamente" — idempotente. */
    @PostMapping("/{id}/dispensar")
    public void dispensar(@PathVariable UUID id) {
        if (!repo.existsById(id)) throw new NotFoundException("Aviso não encontrado.");
        UUID usuario = currentUser.id();
        if (!dispensas.existsById(new NoticeDispensa.Chave(id, usuario))) {
            dispensas.save(new NoticeDispensa(id, usuario));
        }
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
        if (req.exibirDe() != null && req.exibirAte() != null && req.exibirAte().isBefore(req.exibirDe())) {
            throw new br.gov.goias.secami.common.error.DomainExceptions.BusinessException(
                    "A data final da exibição deve ser igual ou posterior à data inicial.");
        }
        // Período sempre vem completo do formulário: nulo limpa o limite.
        n.setExibirDe(req.exibirDe());
        n.setExibirAte(req.exibirAte());
    }
}
