package br.gov.goias.secami.academy.notice;

import jakarta.validation.constraints.NotBlank;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public final class NoticeDtos {

    private NoticeDtos() {}

    public record Response(
            UUID id, String title, String content, String type,
            boolean active, List<String> targetRoles,
            java.time.LocalDate exibirDe, java.time.LocalDate exibirAte,
            OffsetDateTime createdAt) {
        public static Response from(Notice n) {
            return new Response(n.getId(), n.getTitle(), n.getContent(), n.getType(),
                    n.isActive(), n.getTargetRoles(), n.getExibirDe(), n.getExibirAte(), n.getCreatedAt());
        }
    }

    public record UpsertRequest(
            @NotBlank(message = "Informe o título.") String title,
            @NotBlank(message = "Informe o conteúdo.") String content,
            String type,
            Boolean active,
            List<String> targetRoles,
            /** Período de exibição (inclusive); nulos = sem limite. */
            java.time.LocalDate exibirDe,
            java.time.LocalDate exibirAte
    ) {}
}
