package br.gov.goias.secami.accelero;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.accelero.AcceleroRelatorioDtos.RelatorioAcessos;
import br.gov.goias.secami.auth.CurrentUser;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

/** Relatório de entrada/saída/faltas (catraca real + agendamentos) e
 *  sincronização manual com o Accelero, por aluno. */
@RestController
public class AcceleroController {

    private final AcceleroSyncService sync;
    private final StudentRepository students;
    private final CurrentUser currentUser;

    public AcceleroController(AcceleroSyncService sync, StudentRepository students, CurrentUser currentUser) {
        this.sync = sync;
        this.students = students;
        this.currentUser = currentUser;
    }

    @GetMapping("/me/acessos")
    public RelatorioAcessos meusAcessos(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dataInicial,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dataFinal) {
        Student student = students.findByUserId(currentUser.id())
                .orElseThrow(() -> new NotFoundException("Nenhum aluno vinculado a esta conta."));
        return sync.relatorioAcessos(student, dataInicial, dataFinal);
    }

    @GetMapping("/admin/alunos/{id}/acessos")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE','RECEPCAO','PROFESSOR')")
    public RelatorioAcessos acessosDoAluno(
            @PathVariable UUID id,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dataInicial,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dataFinal) {
        Student student = students.findByIdAndDeletedAtIsNull(id)
                .orElseThrow(() -> new NotFoundException("Aluno não encontrado."));
        return sync.relatorioAcessos(student, dataInicial, dataFinal);
    }

    @PostMapping("/admin/alunos/{id}/accelero/sincronizar")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public Map<String, Object> sincronizar(@PathVariable UUID id) {
        Student student = students.findByIdAndDeletedAtIsNull(id)
                .orElseThrow(() -> new NotFoundException("Aluno não encontrado."));
        boolean ok = sync.ressincronizar(student);
        Map<String, Object> resposta = new java.util.HashMap<>();
        resposta.put("vinculado", ok);
        resposta.put("acceleroPessoaId", student.getAcceleroPessoaId());
        return resposta;
    }
}
