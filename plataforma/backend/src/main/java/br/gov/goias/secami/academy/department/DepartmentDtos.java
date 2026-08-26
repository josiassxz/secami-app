package br.gov.goias.secami.academy.department;

import jakarta.validation.constraints.NotBlank;

import java.util.UUID;

public final class DepartmentDtos {

    private DepartmentDtos() {}

    public record Response(UUID id, String name, String sigla, String andar, boolean active) {
        public static Response from(Department d) {
            return new Response(d.getId(), d.getName(), d.getSigla(), d.getAndar(), d.isActive());
        }
    }

    public record UpsertRequest(
            @NotBlank(message = "Informe o nome.") String name,
            String sigla,
            String andar,
            Boolean active
    ) {}
}
