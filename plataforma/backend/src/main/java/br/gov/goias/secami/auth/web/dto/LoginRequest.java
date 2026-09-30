package br.gov.goias.secami.auth.web.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank(message = "Informe o e-mail ou usuário.") String email,
        @NotBlank(message = "Informe a senha.") String password
) {}
