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
        return service.run(resolveDir(dir));
    }

    /** Job separado: baixa as fotos do legado (base44) e vincula aos alunos
     *  já importados. Ver Javadoc de {@link MigrationService#importarFotos}. */
    @PostMapping("/admin/migration/fotos")
    @PreAuthorize("hasRole('ADMIN')")
    public MigrationService.ImportResult fotos(
            @RequestParam(value = "dir", required = false) String dir) {
        return service.importarFotos(resolveDir(dir).resolve("Student_export.csv"));
    }

    /**
     * Atualização incremental dos ALUNOS a partir de uma exportação mais nova
     * do legado (ver {@link MigrationService#atualizarAlunos}). {@code simular=true}
     * (padrão) só relata o que faria — rode assim primeiro e confira.
     *
     * @param baseline pasta da exportação anterior, pra aplicar só o que mudou no legado
     */
    @PostMapping("/admin/migration/alunos")
    @PreAuthorize("hasRole('ADMIN')")
    public MigrationService.AtualizacaoAlunos atualizarAlunos(
            @RequestParam(value = "dir", required = false) String dir,
            @RequestParam(value = "baseline", required = false) String baseline,
            @RequestParam(defaultValue = "true") boolean simular) {
        Path baselineDir = (baseline == null || baseline.isBlank()) ? null : Path.of(baseline);
        return service.atualizarAlunos(resolveDir(dir), baselineDir, simular);
    }

    private Path resolveDir(String dir) {
        String target = (dir != null && !dir.isBlank()) ? dir : defaultDir;
        if (target == null || target.isBlank()) {
            throw new BusinessException("Informe o diretório dos CSVs (?dir=) ou configure secami.migration.source-dir.");
        }
        return Path.of(target);
    }
}
