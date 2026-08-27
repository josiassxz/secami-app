package br.gov.goias.secami.registration;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.common.ValidCpf;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
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
            @NotBlank @Email(message = "Informe um e-mail válido.") String email,
            @NotBlank @Size(min = 8, message = "A senha precisa ter pelo menos 8 caracteres.") String password,
            BigDecimal weightKg,
            BigDecimal heightCm,
            List<String> objetivos,
            @NotBlank(message = "Selecione a categoria (Civil ou Militar).") String studentType,
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
}
