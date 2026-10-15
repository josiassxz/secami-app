package br.gov.goias.secami.common;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class EmailInstitucionalTest {

    @Test
    void normalizaEmailDoDominioInstitucional() {
        assertThat(EmailInstitucional.normalizar("  Fulano.Silva@Goias.gov.br ")).contains("fulano.silva@goias.gov.br");
    }

    @Test
    void aceitaTambemOEmailDeTerceirizado() {
        assertThat(EmailInstitucional.normalizar(" Fulano@Fornecedores.goias.gov.br")).contains("fulano@fornecedores.goias.gov.br");
        assertThat(EmailInstitucional.normalizar("fulano@outro.goias.gov.br")).isEmpty();
    }

    @Test
    void rejeitaOutrosDominiosEValoresVazios() {
        assertThat(EmailInstitucional.normalizar("fulano@gmail.com")).isEmpty();
        assertThat(EmailInstitucional.normalizar("fulano@sub.goias.gov.br.evil.com")).isEmpty();
        assertThat(EmailInstitucional.normalizar("@goias.gov.br")).isEmpty(); // sem parte local
        assertThat(EmailInstitucional.normalizar("  ")).isEmpty();
        assertThat(EmailInstitucional.normalizar(null)).isEmpty();
    }
}
