package br.gov.goias.secami.auth.ldap;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.TestPropertySource;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Lote que traz o e-mail institucional do AD (casando por CPF) pro cadastro do aluno. */
@TestPropertySource(properties = "secami.ldap.enabled=true")
class LdapEmailSyncServiceTest extends AbstractIntegrationTest {

    @Autowired private LdapEmailSyncService sync;
    @Autowired private StudentRepository students;
    @MockBean private LdapDirectory directory;

    private Student aluno(String cpf, String email) {
        Student s = new Student();
        s.setFullName("Aluno AD " + UUID.randomUUID());
        s.setCpf(cpf);
        s.setEmail(email);
        return students.save(s);
    }

    private static LdapUser contaAd(String email) {
        return new LdapUser(UUID.randomUUID(), "sam." + UUID.randomUUID().toString().substring(0, 6), email, "Fulano", null);
    }

    private String emailDe(Student s) {
        return students.findById(s.getId()).orElseThrow().getEmail();
    }

    @Test
    void trocaEmailPessoalPeloInstitucionalDoAdCasandoPorCpf() {
        String cpf = CpfTestFactory.next();
        Student s = aluno(cpf, "pessoal@gmail.com");
        when(directory.buscarPorCpfs(any())).thenReturn(Map.of(cpf, List.of(contaAd("Fulano.Tal@goias.gov.br"))));

        var resumo = sync.atualizarEmails(false);

        assertThat(emailDe(s)).isEqualTo("fulano.tal@goias.gov.br");
        assertThat(resumo.atualizados()).isGreaterThanOrEqualTo(1);
        assertThat(resumo.simulacao()).isFalse();
    }

    @Test
    void simulacaoContaMasNaoGrava() {
        String cpf = CpfTestFactory.next();
        Student s = aluno(cpf, "pessoal@gmail.com");
        when(directory.buscarPorCpfs(any())).thenReturn(Map.of(cpf, List.of(contaAd("fulano.tal@goias.gov.br"))));

        var resumo = sync.atualizarEmails(true);

        assertThat(resumo.atualizados()).isGreaterThanOrEqualTo(1);
        assertThat(resumo.simulacao()).isTrue();
        assertThat(emailDe(s)).isEqualTo("pessoal@gmail.com");
    }

    @Test
    void naoTrocaQuandoOEmailDoAdNaoEInstitucionalOuEstaVazio() {
        String cpfGmail = CpfTestFactory.next();
        String cpfVazio = CpfTestFactory.next();
        Student a = aluno(cpfGmail, "pessoal@gmail.com");
        Student b = aluno(cpfVazio, "outro@hotmail.com");
        when(directory.buscarPorCpfs(any())).thenReturn(Map.of(
                cpfGmail, List.of(contaAd("no.ad.mas.gmail@gmail.com")),
                cpfVazio, List.of(contaAd(null))));

        var resumo = sync.atualizarEmails(false);

        assertThat(emailDe(a)).isEqualTo("pessoal@gmail.com");
        assertThat(emailDe(b)).isEqualTo("outro@hotmail.com");
        assertThat(resumo.semEmailGov()).isGreaterThanOrEqualTo(2);
    }

    @Test
    void cpfComMaisDeUmaContaAtivaNoAdEIgnoradoPorAmbiguidade() {
        String cpf = CpfTestFactory.next();
        Student s = aluno(cpf, "pessoal@gmail.com");
        when(directory.buscarPorCpfs(any())).thenReturn(Map.of(cpf, List.of(
                contaAd("um@goias.gov.br"), contaAd("dois@goias.gov.br"))));

        var resumo = sync.atualizarEmails(false);

        assertThat(emailDe(s)).isEqualTo("pessoal@gmail.com");
        assertThat(resumo.ambiguos()).isGreaterThanOrEqualTo(1);
    }

    @Test
    void cpfSemContaNoAdContaComoNaoEncontradoENaoMexeNoEmail() {
        Student s = aluno(CpfTestFactory.next(), "pessoal@gmail.com");
        when(directory.buscarPorCpfs(any())).thenReturn(Map.of());

        var resumo = sync.atualizarEmails(false);

        assertThat(emailDe(s)).isEqualTo("pessoal@gmail.com");
        assertThat(resumo.naoEncontrados()).isGreaterThanOrEqualTo(1);
    }

    @Test
    void contaSubstituicaoDeOutroEmailInstitucionalSeparadamente() {
        String cpf = CpfTestFactory.next();
        Student s = aluno(cpf, "antigo@goias.gov.br");
        when(directory.buscarPorCpfs(any())).thenReturn(Map.of(cpf, List.of(contaAd("novo@goias.gov.br"))));

        var resumo = sync.atualizarEmails(false);

        assertThat(emailDe(s)).isEqualTo("novo@goias.gov.br");
        assertThat(resumo.substituidosGov()).isGreaterThanOrEqualTo(1);
        assertThat(resumo.substituicoesGov()).anyMatch(m -> m.de().equals("antigo@goias.gov.br")
                && m.para().equals("novo@goias.gov.br"));
    }

    @Test
    void jaCorretoNaoContaComoAtualizado() {
        String cpf = CpfTestFactory.next();
        aluno(cpf, "igual@goias.gov.br");
        when(directory.buscarPorCpfs(any())).thenReturn(Map.of(cpf, List.of(contaAd("IGUAL@goias.gov.br"))));

        var resumo = sync.atualizarEmails(false);

        assertThat(resumo.jaCorretos()).isGreaterThanOrEqualTo(1);
    }

    @Test
    void adForaDoArViraMensagemClaraEmVezDeErro500() throws Exception {
        when(directory.buscarPorCpfs(any())).thenThrow(new LdapUnavailableException("timeout", null));

        mockMvc.perform(authed(post("/admin/jobs/atualizar-emails-ldap?simular=false"), loginAs("admin")))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("consultar o AD")));
    }

    @Test
    void endpointRodaEmSimulacaoPorPadraoESoAdminChama() throws Exception {
        String cpf = CpfTestFactory.next();
        Student s = aluno(cpf, "pessoal@gmail.com");
        when(directory.buscarPorCpfs(any())).thenReturn(Map.of(cpf, List.of(contaAd("fulano@goias.gov.br"))));

        mockMvc.perform(authed(post("/admin/jobs/atualizar-emails-ldap"), loginAs("admin")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.simulacao").value(true));
        assertThat(emailDe(s)).isEqualTo("pessoal@gmail.com");

        mockMvc.perform(authed(post("/admin/jobs/atualizar-emails-ldap"), loginAs("gerente")))
                .andExpect(status().isForbidden());
    }
}
