package br.gov.goias.secami.training.coaching;

import br.gov.goias.secami.identity.AppUser;
import jakarta.validation.constraints.NotBlank;

import java.time.OffsetDateTime;
import java.util.UUID;

public final class CoachDtos {

    private CoachDtos() {}

    public record CriarConviteRequest(String tipo, UUID orgId, Integer usosMax, Integer validadeDias) {}

    public record ConviteResponse(String codigo, OffsetDateTime expiraEm) {
        public static ConviteResponse from(Convite c) {
            return new ConviteResponse(c.getCodigo(), c.getExpiraEm());
        }
    }

    public record ResgatarRequest(@NotBlank(message = "Informe o código.") String codigo) {}

    public record PessoaResumo(UUID id, String nome, String email) {
        public static PessoaResumo from(AppUser u) {
            return new PessoaResumo(u.getId(), u.getNome(), u.getEmail());
        }
    }

    public record VinculoAlunoResponse(UUID id, String status, OffsetDateTime aceitoEm, PessoaResumo aluno) {}

    public record VinculoTreinadorResponse(UUID id, String status, PessoaResumo professor) {}
}
