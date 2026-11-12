package br.gov.goias.secami.academy.punicao;

import br.gov.goias.secami.academy.punicao.PunicaoService.AlunoLutas;
import br.gov.goias.secami.academy.punicao.PunicaoService.AplicarRequest;
import br.gov.goias.secami.academy.punicao.PunicaoService.ItemDto;
import br.gov.goias.secami.academy.punicao.PunicaoService.ItemRequest;
import br.gov.goias.secami.academy.punicao.PunicaoService.PunicaoDto;
import br.gov.goias.secami.auth.CurrentUser;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/** Punições: instrutor de lutas (papel "lutas") e admin; o aluno vê as dele em /me/punicoes. */
@RestController
public class PunicaoController {

    private final PunicaoService service;
    private final CurrentUser currentUser;

    public PunicaoController(PunicaoService service, CurrentUser currentUser) {
        this.service = service;
        this.currentUser = currentUser;
    }

    @GetMapping("/punicoes/itens")
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    public List<ItemDto> itens(@RequestParam(defaultValue = "false") boolean todos) {
        return service.listarItens(todos);
    }

    @PostMapping("/punicoes/itens")
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    public ItemDto criarItem(@RequestBody ItemRequest req) {
        return service.criarItem(req);
    }

    @PutMapping("/punicoes/itens/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    public ItemDto editarItem(@PathVariable UUID id, @RequestBody ItemRequest req) {
        return service.editarItem(id, req);
    }

    @GetMapping("/punicoes/alunos")
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    public List<AlunoLutas> alunos(@RequestParam(required = false) String q) {
        return service.alunos(q);
    }

    @GetMapping("/punicoes/alunos/{studentId}")
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    public List<PunicaoDto> emAberto(@PathVariable UUID studentId) {
        return service.emAberto(studentId);
    }

    @GetMapping("/punicoes/alunos/{studentId}/historico")
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    public List<PunicaoDto> historico(@PathVariable UUID studentId) {
        return service.historico(studentId);
    }

    // "/punicoes" sozinho é a tela do admin (o nginx serve a página nesse caminho
    // e devolvia 405 pro POST) — aplicar fica em /punicoes/aplicar.
    @PostMapping({"/punicoes/aplicar", "/punicoes"})
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    public PunicaoDto aplicar(@RequestBody AplicarRequest req) {
        return service.aplicar(req, currentUser.id());
    }

    @PostMapping("/punicoes/{id}/cumprir")
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    public List<PunicaoDto> cumprir(@PathVariable UUID id) {
        return service.cumprir(id, currentUser.id());
    }

    @DeleteMapping("/punicoes/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','LUTAS')")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void excluir(@PathVariable UUID id) {
        service.excluir(id);
    }

    @GetMapping("/me/punicoes")
    public List<PunicaoDto> minhas() {
        return service.minhas(currentUser.id());
    }
}
