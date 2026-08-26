package br.gov.goias.secami.auth.web.dto;

import br.gov.goias.secami.identity.AppUser;

import java.util.List;
import java.util.UUID;

public record MeResponse(
        UUID id,
        String samAccountName,
        String nome,
        String email,
        String tipoIdentidade,
        boolean ativo,
        List<String> roles
) {
    public static MeResponse from(AppUser u) {
        return new MeResponse(
                u.getId(),
                u.getSamAccountName(),
                u.getNome(),
                u.getEmail(),
                u.getTipoIdentidade(),
                u.isAtivo(),
                List.copyOf(u.getRoles())
        );
    }
}
