package br.gov.goias.secami.academy.atestado;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public final class AtestadoDtos {

    private AtestadoDtos() {}

    public static final String OK = "OK";
    public static final String VENCENDO = "VENCENDO";
    public static final String VENCIDO = "VENCIDO";

    /** Situação do atestado do próprio aluno (app). Com {@code aplicavel=false}
     *  (militar, instrutor ou conta sem cadastro de aluno) os demais campos vêm nulos
     *  e são omitidos do JSON. */
    public record Status(
            boolean aplicavel,
            String situacao,          // OK | VENCENDO (0–30 dias) | VENCIDO
            Boolean bloqueado,
            LocalDate vencimento,
            Long diasRestantes,       // negativo quando vencido
            String base,              // ATESTADO | CADASTRO
            Envio envio) {

        public static Status naoAplicavel() {
            return new Status(false, null, null, null, null, null, null);
        }
    }

    /** Envio que ainda importa pro aluno: em análise, ou recusado e não substituído. */
    public record Envio(UUID id, String status, OffsetDateTime enviadoEm, LocalDate emissaoData, String motivoRecusa) {
        public static Envio from(AtestadoEnvio e) {
            return new Envio(e.getId(), e.getStatus(), e.getEnviadoEm(), e.getEmissaoData(),
                    AtestadoEnvio.RECUSADO.equals(e.getStatus()) ? e.getMotivoRecusa() : null);
        }
    }

    /** Parte JSON ({@code dados}) do envio multipart. */
    public record EnvioRequest(
            @NotNull(message = "Informe a data de emissão do atestado.") LocalDate emissaoData,
            @NotBlank(message = "Informe o nome do médico.") String medicoNome,
            @NotBlank(message = "Informe o CRM do médico.") String medicoCrm,
            @NotBlank(message = "Informe a UF do CRM.") String medicoCrmUf) {}

    /** Item da fila de validação (admin). */
    public record Pendente(
            UUID id, UUID studentId, String studentName, String cpf, String email, String phone,
            String departmentName, OffsetDateTime enviadoEm, LocalDate emissaoData,
            String medicoNome, String medicoCrm, String medicoCrmUf, UUID arquivoId,
            LocalDate vencimentoAtual, Long diasRestantesAtual, boolean bloqueado) {}

    public record RecusarRequest(@NotBlank(message = "Informe o motivo da recusa.") String motivo) {}

    /** Linha das listas "vencem em 30 dias" e "bloqueados" do painel. */
    public record AlunoAtestado(
            UUID studentId, String studentName, String cpf, String departmentName, String phone,
            LocalDate vencimento, long diasRestantes, String base, boolean bloqueado, boolean envioEmAnalise) {}

    public record Resumo(long vencendo, long bloqueados, long pendentes) {}

    /** Resultado do job/gatilho de bloqueio. */
    public record ResultadoBloqueio(int bloqueados, int desbloqueados, int agendamentosCancelados) {}
}
