package br.gov.goias.secami.registration;

import br.gov.goias.secami.academy.department.DepartmentDtos;
import br.gov.goias.secami.academy.department.DepartmentRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.registration.RegistrationDtos.CadastroRequest;
import br.gov.goias.secami.registration.RegistrationDtos.CadastroResponse;
import br.gov.goias.secami.registration.RegistrationDtos.PendenteResponse;
import br.gov.goias.secami.registration.RegistrationDtos.RejeitarRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
public class RegistrationController {

    private final RegistrationService service;
    private final DepartmentRepository departments;

    public RegistrationController(RegistrationService service, DepartmentRepository departments) {
        this.service = service;
        this.departments = departments;
    }

    /** Lista pra popular o combo "Secretaria/órgão" do formulário público. */
    @GetMapping("/cadastro/departamentos")
    public List<DepartmentDtos.Response> departamentos() {
        return departments.findAll().stream()
                .filter(d -> d.isActive())
                .map(DepartmentDtos.Response::from)
                .toList();
    }

    /** Cadastro público — sem autenticação (é assim que o aluno vira aluno). */
    @PostMapping(value = "/cadastro", consumes = "multipart/form-data")
    @ResponseStatus(HttpStatus.CREATED)
    public CadastroResponse cadastrar(@RequestPart("dados") @Valid CadastroRequest dados,
                                       @RequestPart("atestado") MultipartFile atestado) {
        Student s = service.cadastrar(dados, atestado);
        return new CadastroResponse(s.getId(), s.getStatusCadastro());
    }

    @GetMapping("/admin/cadastros/pendentes")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public List<PendenteResponse> pendentes() {
        return service.listarPendentes().stream().map(PendenteResponse::from).toList();
    }

    @PostMapping("/admin/cadastros/{id}/aprovar")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public PendenteResponse aprovar(@PathVariable UUID id) {
        return PendenteResponse.from(service.aprovar(id));
    }

    @PostMapping("/admin/cadastros/{id}/rejeitar")
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public PendenteResponse rejeitar(@PathVariable UUID id, @Valid @RequestBody RejeitarRequest req) {
        return PendenteResponse.from(service.rejeitar(id, req.motivo()));
    }
}
