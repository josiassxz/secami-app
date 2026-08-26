package br.gov.goias.secami.academy.student;

import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.common.ValidCpf;
import jakarta.validation.constraints.NotBlank;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.UUID;

public final class StudentDtos {

    private StudentDtos() {}

    public record Response(
            UUID id, String fullName, String cpf, String matricula, String studentType,
            UUID departmentId, String departmentName, String phone, String email,
            LocalDate birthDate, BigDecimal weightKg, BigDecimal heightCm, String goal,
            UUID photoId, String atestadoNumero, LocalDate atestadoData,
            boolean active, boolean atestadoValido) {

        public static Response from(Student s, boolean maskCpf) {
            String cpf = maskCpf ? Cpf.mask(s.getCpf()) : Cpf.format(s.getCpf());
            return new Response(
                    s.getId(), s.getFullName(), cpf, s.getMatricula(), s.getStudentType(),
                    s.getDepartment() != null ? s.getDepartment().getId() : null,
                    s.getDepartment() != null ? s.getDepartment().getName() : null,
                    s.getPhone(), s.getEmail(), s.getBirthDate(), s.getWeightKg(), s.getHeightCm(),
                    s.getGoal(), s.getPhotoId(), s.getAtestadoNumero(), s.getAtestadoData(),
                    s.isActive(), s.atestadoValido(LocalDate.now()));
        }
    }

    public record UpsertRequest(
            @NotBlank(message = "Informe o nome completo.") String fullName,
            @ValidCpf String cpf,
            String matricula,
            String studentType,     // Civil | Militar
            UUID departmentId,
            String phone,
            String email,
            LocalDate birthDate,
            BigDecimal weightKg,
            BigDecimal heightCm,
            String goal,
            UUID photoId,
            String atestadoNumero,
            LocalDate atestadoData,
            Boolean active
    ) {}

    /** Aluno edita apenas o próprio perfil. */
    public record MeUpdateRequest(
            String phone,
            BigDecimal weightKg,
            BigDecimal heightCm,
            String goal,
            UUID photoId
    ) {}
}
