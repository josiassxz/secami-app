package br.gov.goias.secami.common.error;

import java.time.OffsetDateTime;
import java.util.List;

/** Corpo padrão de erro da API. */
public record ApiError(
        OffsetDateTime timestamp,
        int status,
        String error,
        String message,
        String path,
        List<FieldError> fieldErrors
) {
    public record FieldError(String field, String message) {}
}
