package br.gov.goias.secami.training.exercise;

import jakarta.validation.constraints.NotBlank;

import java.util.UUID;

public final class ExerciseDtos {

    private ExerciseDtos() {}

    public record Response(
            UUID id, String name, String slug, String muscleGroup, String description,
            String equipment, String padraoMovimento, String videoUrl,
            UUID photoId, String escopo, boolean arquivado) {
        public static Response from(Exercise e) {
            return new Response(e.getId(), e.getName(), e.getSlug(), e.getMuscleGroup(), e.getDescription(),
                    e.getEquipment(), e.getPadraoMovimento(), e.getVideoUrl(),
                    e.getPhotoId(), e.getEscopo(), e.isArquivado());
        }
    }

    public record UpsertRequest(
            @NotBlank(message = "Informe o nome.") String name,
            String muscleGroup,
            String description,
            String equipment,
            String padraoMovimento,
            String videoUrl,
            UUID photoId,
            Boolean arquivado
    ) {}
}
