package br.gov.goias.secami.common;

import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Testes unitários (sem contexto Spring) do utilitário de CPF: normalização,
 * formatação, mascaramento (LGPD, SPEC §14) e validação de dígitos
 * verificadores (SPEC §8.2: "cpf ... validado").
 */
class CpfTest {

    // ---- normalize ----

    @Test
    void normalizeRemoveTudoQueNaoEDigito() {
        assertThat(Cpf.normalize("390.533.447-05")).isEqualTo("39053344705");
    }

    @Test
    void normalizeComNuloRetornaNulo() {
        assertThat(Cpf.normalize(null)).isNull();
    }

    @Test
    void normalizeComStringSoPontuacaoRetornaNulo() {
        assertThat(Cpf.normalize("...-")).isNull();
    }

    // ---- format ----

    @Test
    void formatColocaMascaraPadrao() {
        assertThat(Cpf.format("39053344705")).isEqualTo("390.533.447-05");
    }

    @Test
    void formatComTamanhoDiferenteDe11DevolveComoEsta() {
        assertThat(Cpf.format("123")).isEqualTo("123");
        assertThat(Cpf.format(null)).isNull();
    }

    // ---- mask (LGPD) ----

    @Test
    void maskEsconceMiolhoDoCpfMasMantemInicioEFim() {
        String masked = Cpf.mask("39053344705");
        assertThat(masked).isEqualTo("390.***.***-05");
        // Garante que os dígitos do meio realmente não aparecem em nenhum lugar da string.
        assertThat(masked).doesNotContain("533").doesNotContain("447");
    }

    @Test
    void maskComTamanhoDiferenteDe11DevolveComoEsta() {
        assertThat(Cpf.mask("123")).isEqualTo("123");
        assertThat(Cpf.mask(null)).isNull();
    }

    // ---- isValid ----

    @ParameterizedTest
    @ValueSource(strings = {"39053344705", "111.444.777-35", "11144477735"})
    void isValidAceitaCpfComDigitosVerificadoresCorretos(String cpf) {
        assertThat(Cpf.isValid(cpf)).isTrue();
    }

    @Test
    void isValidRejeitaDigitoVerificadorErrado() {
        // 39053344705 é válido; troca o último dígito -> verificador quebra.
        assertThat(Cpf.isValid("39053344700")).isFalse();
    }

    @ParameterizedTest
    @ValueSource(strings = {
            "00000000000", "11111111111", "22222222222", "33333333333",
            "44444444444", "55555555555", "66666666666", "77777777777",
            "88888888888", "99999999999"
    })
    void isValidRejeitaSequenciasDeDigitoRepetido(String cpf) {
        // Passariam no cálculo de módulo 11, mas não são CPFs reais.
        assertThat(Cpf.isValid(cpf)).isFalse();
    }

    @Test
    void isValidRejeitaTamanhoErrado() {
        assertThat(Cpf.isValid("123456789")).isFalse();
        assertThat(Cpf.isValid("123456789012")).isFalse();
    }

    @Test
    void isValidRejeitaNuloOuVazio() {
        assertThat(Cpf.isValid(null)).isFalse();
        assertThat(Cpf.isValid("")).isFalse();
        assertThat(Cpf.isValid("   ")).isFalse();
    }

    @Test
    void isValidAceitaCpfGeradoPelaFabricaDeTestes() {
        for (int i = 0; i < 50; i++) {
            String cpf = CpfTestFactory.next();
            assertThat(Cpf.isValid(cpf))
                    .as("CPF gerado pela fábrica de testes deve ser válido: %s", cpf)
                    .isTrue();
        }
    }
}
