package br.gov.goias.secami.auth.ldap;

import java.util.UUID;

/** Dados do usuário no AD, já autenticado (senha conferida por bind). */
public record LdapUser(UUID guid, String samAccountName, String email, String nome, String cpf) {}
