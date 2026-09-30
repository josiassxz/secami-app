package br.gov.goias.secami.auth.ldap;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** Funções puras da consulta ao AD — sem rede. */
class JndiLdapDirectoryTest {

    private static final String USER_FILTER = "(objectClass=user)";

    @Test
    void loginPorUsuarioBuscaPeloAtributoDeLogin() {
        assertThat(JndiLdapDirectory.montarFiltro(USER_FILTER, "sAMAccountName", "josias.ssiqueira"))
                .isEqualTo("(&(objectClass=user)(sAMAccountName=josias.ssiqueira))");
    }

    @Test
    void loginPorEmailBuscaPorUpnOuMail() {
        assertThat(JndiLdapDirectory.montarFiltro(USER_FILTER, "sAMAccountName", "fulano@goias.gov.br"))
                .isEqualTo("(&(objectClass=user)(|(userPrincipalName=fulano@goias.gov.br)(mail=fulano@goias.gov.br)))");
    }

    @Test
    void escapaMetacaracteresPraImpedirInjecaoDeFiltro() {
        // "*)(uid=*" tentaria virar um filtro que casa com qualquer usuário.
        String filtro = JndiLdapDirectory.montarFiltro(USER_FILTER, "sAMAccountName", "*)(uid=*");

        assertThat(filtro).isEqualTo("(&(objectClass=user)(sAMAccountName=\\2a\\29\\28uid=\\2a))");
        assertThat(JndiLdapDirectory.escaparFiltro("a\\b\0c")).isEqualTo("a\\5cb\\00c");
    }

    @Test
    void extraiCpfValidoDoTextoLivreDoAd() {
        assertThat(JndiLdapDirectory.extrairCpf("111.444.777-35")).isEqualTo("11144477735");
        assertThat(JndiLdapDirectory.extrairCpf("CPF 11144477735 - SGG")).isEqualTo("11144477735");
    }

    @Test
    void ignoraTextoSemCpfValido() {
        assertThat(JndiLdapDirectory.extrairCpf(null)).isNull();
        assertThat(JndiLdapDirectory.extrairCpf("Servidor da SGG")).isNull();
        assertThat(JndiLdapDirectory.extrairCpf("111.111.111-11")).isNull(); // passa no módulo 11, mas não é CPF real
        assertThat(JndiLdapDirectory.extrairCpf("123.456.789-00")).isNull(); // dígito verificador errado
    }

    @Test
    void convertePraGuidCanonicoDoAdComOsTresPrimeirosCamposLittleEndian() {
        byte[] bytes = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16};

        assertThat(JndiLdapDirectory.guidDeBytes(bytes))
                .isEqualTo(UUID.fromString("04030201-0605-0807-090a-0b0c0d0e0f10"));
    }

    @Test
    void guidComTamanhoErradoViraNulo() {
        assertThat(JndiLdapDirectory.guidDeBytes(new byte[] {1, 2, 3})).isNull();
        assertThat(JndiLdapDirectory.guidDeBytes(null)).isNull();
    }

    @Test
    void filtroPorCpfsCasaOsDoisFormatosComoSubstringDoTextoLivre() {
        String filtro = JndiLdapDirectory.montarFiltroPorCpfs(USER_FILTER, "description",
                java.util.List.of("11144477735", "52998224725"));

        assertThat(filtro).isEqualTo("(&(objectClass=user)(|"
                + "(description=*111.444.777-35*)(description=*11144477735*)"
                + "(description=*529.982.247-25*)(description=*52998224725*)))");
    }
}
