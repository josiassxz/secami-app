package br.gov.goias.secami.migration;

import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.nio.file.Path;
import java.util.List;

/** Dispara a migração dos CSVs legados. Apenas admin. SPEC §13. */
@RestController
public class MigrationController {

    private final MigrationService service;
    private final String defaultDir;

    public MigrationController(MigrationService service,
                              @Value("${secami.migration.source-dir:}") String defaultDir) {
        this.service = service;
        this.defaultDir = defaultDir;
    }

    @PostMapping("/admin/migration/run")
    @PreAuthorize("hasRole('ADMIN')")
    public List<MigrationService.ImportResult> run(
            @RequestParam(value = "dir", required = false) String dir) {
        String target = (dir != null && !dir.isBlank()) ? dir : defaultDir;
        if (target == null || target.isBlank()) {
            throw new BusinessException("Informe o diretório dos CSVs (?dir=) ou configure secami.migration.source-dir.");
        }
        return service.run(Path.of(target));
    }
}
