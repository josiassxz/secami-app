package br.gov.goias.secami.academy.atestado;

import br.gov.goias.secami.academy.atestado.AtestadoDtos.AlunoAtestado;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.Envio;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.EnvioRequest;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.Pendente;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.RecusarRequest;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.ResultadoBloqueio;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.Resumo;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.Status;
import br.gov.goias.secami.auth.CurrentUser;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

/** Atestado médico: situação e envio pelo aluno; fila de validação e painel do admin. */
@RestController
public class AtestadoController {

    private final AtestadoService service;
    private final CurrentUser currentUser;

    public AtestadoController(AtestadoService service, CurrentUser currentUser) {
        this.service = service;
        this.currentUser = currentUser;
    }

    // ---- aluno ----

    /** Situação do atestado do próprio aluno (o app decide se mostra o aviso). */
    @GetMapping("/me/atestado")
    public Status meuStatus() {
        return service.statusDoUsuario(currentUser.id());
    }

    /** Envia um novo atestado (PDF) — vai pra fila de validação do admin. */
    @PostMapping(value = "/me/atestado", consumes = "multipart/form-data")
    @ResponseStatus(HttpStatus.CREATED)
    public Envio enviar(@RequestPart("dados") @Valid EnvioRequest dados,
                        @RequestPart("arquivo") MultipartFile arquivo) {
        return service.enviar(currentUser.id(), dados, arquivo);
    }

    // ---- admin ----

    @GetMapping("/admin/atestados/pendentes")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public List<Pendente> pendentes() {
        return service.pendentes();
    }

    @PostMapping("/admin/atestados/{id}/aprovar")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Envio aprovar(@PathVariable UUID id) {
        return service.aprovar(id, currentUser.id());
    }

    @PostMapping("/admin/atestados/{id}/recusar")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Envio recusar(@PathVariable UUID id, @Valid @RequestBody RecusarRequest req) {
        return service.recusar(id, req.motivo(), currentUser.id());
    }

    /** Indicadores do painel: vencem em 30 dias, bloqueados, aguardando validação. */
    @GetMapping("/admin/atestados/resumo")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO')")
    public Resumo resumo() {
        return service.resumo();
    }

    /** @param lista {@code vencendo} (0–30 dias) ou {@code bloqueados} */
    @GetMapping("/admin/atestados/alunos")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO')")
    public List<AlunoAtestado> alunos(@RequestParam String lista) {
        return service.alunos(lista);
    }

    /** Gatilho manual da rotina diária de bloqueio/desbloqueio (operação/testes). */
    @PostMapping("/admin/jobs/bloquear-atestados-vencidos")
    @PreAuthorize("hasRole('ADMIN')")
    public ResultadoBloqueio aplicarBloqueios() {
        return service.aplicarBloqueios();
    }
}
