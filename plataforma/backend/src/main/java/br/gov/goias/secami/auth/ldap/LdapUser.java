package br.gov.goias.secami.auth.ldap;

import java.util.UUID;

/** Dados do usuário no AD, já autenticado (senha conferida por bind).
 *  {@code email} = mail (ou o UPN, se não houver mail); {@code upn} = userPrincipalName,
 *  que pode ser diferente do mail (ex.: mail johnathan-ps@, UPN johnathan.sousa@). */
public record LdapUser(UUID guid, String samAccountName, String email, String nome, String cpf, String upn) {

    public LdapUser(UUID guid, String samAccountName, String email, String nome, String cpf) {
        this(guid, samAccountName, email, nome, cpf, null);
    }

    /** E-mails pelos quais a conta pode ser achada aqui: o mail e, se diferente, o UPN. */
    public java.util.List<String> emails() {
        return java.util.stream.Stream.of(email, upn)
                .filter(e -> e != null && !e.isBlank())
                .map(e -> e.trim().toLowerCase())
                .distinct()
                .toList();
    }
}
