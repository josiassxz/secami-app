package br.gov.goias.secami.identity.web;

import br.gov.goias.secami.auth.web.dto.MeResponse;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/users")
public class UserController {

    private final AppUserRepository users;

    public UserController(AppUserRepository users) {
        this.users = users;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','GERENTE')")
    public List<MeResponse> list(@RequestParam(value = "q", required = false) String q) {
        List<AppUser> found = (q == null || q.isBlank())
                ? users.findAll()
                : users.findByNomeContainingIgnoreCaseOrEmailContainingIgnoreCase(q, q);
        return found.stream().map(MeResponse::from).toList();
    }

    @PatchMapping("/{id}/roles")
    @PreAuthorize("hasRole('ADMIN')")
    public MeResponse updateRoles(@PathVariable UUID id, @Valid @RequestBody UpdateRolesRequest req) {
        for (String r : req.roles()) {
            if (!Roles.ALL.contains(r)) {
                throw new BusinessException("Papel inválido: " + r);
            }
        }
        AppUser user = users.findById(id)
                .orElseThrow(() -> new NotFoundException("Usuário não encontrado."));
        user.getRoles().clear();
        user.getRoles().addAll(req.roles());
        return MeResponse.from(users.save(user));
    }
}
