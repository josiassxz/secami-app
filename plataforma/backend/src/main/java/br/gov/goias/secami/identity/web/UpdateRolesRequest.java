package br.gov.goias.secami.identity.web;

import jakarta.validation.constraints.NotEmpty;

import java.util.Set;

public record UpdateRolesRequest(
        @NotEmpty(message = "Informe ao menos um papel.") Set<String> roles
) {}
