package br.gov.goias.secami.academy.configuracao;

import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class ConfiguracaoController {

    public record Catraca(Integer janelaHoras) {}

    private final ConfiguracaoService service;

    public ConfiguracaoController(ConfiguracaoService service) {
        this.service = service;
    }

    @GetMapping("/admin/configuracoes/catraca")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Catraca catraca() {
        return new Catraca(service.janelaCatracaHoras());
    }

    @GetMapping("/admin/configuracoes/lutas")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public ConfiguracaoService.Lutas lutas() {
        return service.lutas();
    }

    /** Vale a partir da próxima liberação do dia (a de hoje, se já feita, fica como está). */
    @PutMapping("/admin/configuracoes/lutas")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public ConfiguracaoService.Lutas definirLutas(@RequestBody ConfiguracaoService.Lutas req) {
        return service.definirLutas(req);
    }

    /** Vale pros próximos agendamentos; os já liberados mantêm a janela da época. */
    @PutMapping("/admin/configuracoes/catraca")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Catraca definirCatraca(@RequestBody Catraca req) {
        return new Catraca(service.definirJanelaCatracaHoras(req.janelaHoras()));
    }
}
