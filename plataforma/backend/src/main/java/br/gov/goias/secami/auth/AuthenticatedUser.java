package br.gov.goias.secami.auth;

import java.util.UUID;

/**
 * Resultado de uma autenticação bem-sucedida por um {@link AuthProvider}.
 * Usado para provisionamento just-in-time do {@code app_user} (SPEC §12.2).
 */
public record AuthenticatedUser(
        UUID ldapGuid,       // objectGUID (null para identidade local/dev)
        String samAccountName,
        String email,
        String nome,
        String tipoIdentidade   // "ad" | "local"
) {}
