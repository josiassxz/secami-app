package br.gov.goias.secami.registration;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.common.ValidCpf;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public final class RegistrationDtos {

    private RegistrationDtos() {}

    /** Cadastro público (formulário "ACADEMIA ESPAÇO SAÚDE") — parte JSON do multipart. */
    public record CadastroRequest(
            @NotBlank(message = "Informe o nome completo.") String fullName,
            @ValidCpf String cpf,
            @NotNull(message = "Informe a data de nascimento.") LocalDate birthDate,
            @NotBlank(message = "Informe o WhatsApp para contato.") String whatsapp,
            @NotNull(message = "Selecione a secretaria/órgão.") UUID departmentId,
            @NotBlank @Email(message = "Informe um e-mail válido.")
            @Pattern(regexp = "(?i)^[^@\\s]+@goias\\.gov\\.br$",
                    message = "O e-mail precisa ser do domínio @goias.gov.br.")
            String email,
            @NotBlank @Size(min = 8, message = "A senha precisa ter pelo menos 8 caracteres.") String password,
            BigDecimal weightKg,
            BigDecimal heightCm,
            List<String> objetivos,
            @NotNull(message = "Responda o questionário PAR-Q completo.") Map<String, Boolean> parQ,
            @AssertTrue(message = "É necessário aceitar a declaração e o termo de responsabilidade.")
            boolean termoResponsabilidade,
            @AssertTrue(message = "É necessário aceitar o termo de ciência.")
            boolean termoCiencia,
            @NotBlank(message = "Informe o nome completo do médico.") String medicoNome,
            @NotBlank(message = "Informe o CRM do médico.") String medicoCrm,
            @NotBlank(message = "Informe o estado (UF) do CRM.") String medicoCrmUf,
            @NotNull(message = "Informe a data de emissão do atestado.") LocalDate atestadoEmissaoData
    ) {}

    public record CadastroResponse(UUID studentId, String status) {}

    /** Item da fila de aprovação (admin). */
    public record PendenteResponse(
            UUID studentId, String fullName, String cpf, String email, String phone,
            String studentType, LocalDate birthDate, BigDecimal weightKg, BigDecimal heightCm,
            List<String> objetivos, String departmentName, Map<String, Boolean> parQ,
            OffsetDateTime termoResponsabilidadeAceitoEm, OffsetDateTime termoCienciaAceitoEm,
            String medicoNome, String medicoCrm, String medicoCrmUf, LocalDate atestadoEmissaoData,
            UUID atestadoArquivoId, OffsetDateTime createdAt) {

        public static PendenteResponse from(Student s) {
            return new PendenteResponse(
                    s.getId(), s.getFullName(), s.getCpf(), s.getEmail(), s.getPhone(),
                    s.getStudentType(), s.getBirthDate(), s.getWeightKg(), s.getHeightCm(),
                    s.getObjetivos(),
                    s.getDepartment() != null ? s.getDepartment().getName() : null,
                    s.getParQ(),
                    s.getTermoResponsabilidadeAceitoEm(), s.getTermoCienciaAceitoEm(),
                    s.getMedicoNome(), s.getMedicoCrm(), s.getMedicoCrmUf(), s.getAtestadoEmissaoData(),
                    s.getAtestadoArquivoId(), s.getCreatedAt());
        }
    }

    public record RejeitarRequest(@NotBlank(message = "Informe o motivo da recusa.") String motivo) {}

    /** Cria login pra um aluno sem conta (ex.: migrado do legado). */
    public record CriarAcessoRequest(
            @NotBlank @Email(message = "Informe um e-mail válido.") String email,
            @NotBlank @Size(min = 8, message = "A senha precisa ter pelo menos 8 caracteres.") String password) {}

    /**
     * Decisão do admin no momento da aprovação — não no cadastro público:
     * o perfil ({@code aluno}, padrão, ou {@code instrutor}) e, pra aluno, a
     * categoria (Civil/Militar). Instrutor não tem categoria.
     */
    public record AprovarRequest(String studentType, String perfil) {

        public static final String PERFIL_ALUNO = "aluno";
        public static final String PERFIL_INSTRUTOR = "instrutor";

        public boolean instrutor() {
            return perfil != null && PERFIL_INSTRUTOR.equalsIgnoreCase(perfil.trim());
        }

        @com.fasterxml.jackson.annotation.JsonIgnore
        @AssertTrue(message = "Selecione a categoria (Civil ou Militar).")
        public boolean isCategoriaInformada() {
            return instrutor() || (studentType != null && !studentType.isBlank());
        }
    }

    /** Resultado do provisionamento em massa de acesso pros alunos migrados do legado. */
    public record AcessoCriado(UUID studentId, String fullName, String email, String senhaGerada) {}

    public record AcessoPulado(UUID studentId, String fullName, String motivo) {}

    public record CriarAcessosEmMassaResponse(
            List<AcessoCriado> criados, List<AcessoPulado> pulados) {}
}
