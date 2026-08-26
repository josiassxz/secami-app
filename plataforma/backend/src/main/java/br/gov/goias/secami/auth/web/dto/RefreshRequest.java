package br.gov.goias.secami.auth.web.dto;

import jakarta.validation.constraints.NotBlank;

public record RefreshRequest(
        @NotBlank(message = "Informe o refresh token.") String refreshToken
) {}
