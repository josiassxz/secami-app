package br.gov.goias.secami.common;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Valida CPF (dígitos verificadores, SPEC §8.2 "cpf ... validado") quando o
 * campo não é nulo/vazio — o campo continua opcional; para exigir presença,
 * combine com {@code @NotBlank}.
 */
@Target({ElementType.FIELD, ElementType.PARAMETER, ElementType.RECORD_COMPONENT})
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ValidCpf.CpfConstraintValidator.class)
public @interface ValidCpf {

    String message() default "CPF inválido.";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};

    class CpfConstraintValidator implements ConstraintValidator<ValidCpf, String> {
        @Override
        public boolean isValid(String value, ConstraintValidatorContext context) {
            if (value == null || value.isBlank()) return true; // opcional
            return Cpf.isValid(value);
        }
    }
}
