package br.gov.goias.secami.auth;

import br.gov.goias.secami.common.error.DomainExceptions.ForbiddenException;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.UUID;

/** Resolve o usuário autenticado a partir do SecurityContext (subject = app_user.id). */
@Component
public class CurrentUser {

    private final AppUserRepository users;

    public CurrentUser(AppUserRepository users) {
        this.users = users;
    }

    public UUID id() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || auth.getPrincipal() == null) {
            throw new ForbiddenException("Não autenticado.");
        }
        return UUID.fromString(auth.getPrincipal().toString());
    }

    public AppUser require() {
        return users.findById(id())
                .orElseThrow(() -> new ForbiddenException("Usuário não encontrado."));
    }

    public boolean hasRole(String role) {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null) return false;
        String authority = "ROLE_" + role.toUpperCase();
        return auth.getAuthorities().stream().anyMatch(a -> a.getAuthority().equals(authority));
    }
}
