package br.gov.goias.secami.auth.ldap;

import com.fasterxml.jackson.databind.node.ObjectNode;
import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.ResultActions;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Login com a conta do governo (AD) de ponta a ponta pelo /auth/login, com o
 * diretório mockado (só o DC real é alcançável da rede do governo). O que está
 * sob teste é a regra: o AD prova a identidade, mas quem entra é sempre uma
 * conta local já existente, vinculada por objectGUID / e-mail / CPF.
 */
@TestPropertySource(properties = "secami.ldap.enabled=true")
class LdapLoginIntegrationTest extends AbstractIntegrationTest {

    @Autowired private AppUserRepository users;
    @Autowired private StudentRepository students;
    @Autowired private PasswordEncoder encoder;
    @MockBean private LdapDirectory directory;
    @Autowired private br.gov.goias.secami.academy.department.DepartmentRepository departments;

    private AppUser contaLocal(String email, boolean ativo) {
        AppUser u = new AppUser();
        u.setNome("Conta " + UUID.randomUUID());
        u.setEmail(email);
        u.setTipoIdentidade("local");
        u.setAtivo(ativo);
        u.setPasswordHash(encoder.encode("senha-local-123"));
        u.getRoles().add(Roles.ALUNO);
        return users.save(u);
    }

    private ResultActions login(String identificador, String senha) throws Exception {
        return mockMvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of("email", identificador, "password", senha))));
    }

    private static String emailGov() { return "ad." + UUID.randomUUID() + "@goias.gov.br"; }

    private static String sam() { return "sam." + UUID.randomUUID().toString().substring(0, 8); }

    @Test
    void entraComASenhaDoGovernoQuandoOEmailDoAdBateComAContaLocal() throws Exception {
        String email = emailGov();
        AppUser conta = contaLocal(email, true);
        UUID guid = UUID.randomUUID();
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(guid, sam, email, "Fulano de Tal", null)));

        login(sam, "senha-do-governo").andExpect(status().isOk()).andExpect(jsonPath("$.accessToken").exists());

        AppUser vinculada = users.findById(conta.getId()).orElseThrow();
        assertThat(vinculada.getLdapGuid()).isEqualTo(guid);
        assertThat(vinculada.getSamAccountName()).isEqualTo(sam);
    }

    @Test
    void depoisDeVinculadoOGuidBastaMesmoSeOEmailMudarNoAd() throws Exception {
        AppUser conta = contaLocal(emailGov(), true);
        UUID guid = UUID.randomUUID();
        conta.setLdapGuid(guid);
        users.save(conta);
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(guid, sam, "outro.email@goias.gov.br", "Fulano", null)));

        login(sam, "senha-do-governo").andExpect(status().isOk());
    }

    @Test
    void vinculaPeloCpfDoAdQuandoOEmailCadastradoEPessoal() throws Exception {
        String cpf = CpfTestFactory.next();
        AppUser conta = contaLocal("pessoal." + UUID.randomUUID() + "@gmail.com", true);
        Student aluno = new Student();
        aluno.setFullName("Josias Silva Siqueira");
        aluno.setCpf(cpf);
        aluno.setUserId(conta.getId());
        students.save(aluno);
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, emailGov(), "Josias Silva Siqueira", cpf)));

        login(sam, "senha-do-governo").andExpect(status().isOk());

        assertThat(users.findById(conta.getId()).orElseThrow().getLdapGuid()).isNotNull();
    }

    @Test
    void recusaVinculoPorCpfQuandoOPrimeiroNomeNaoBate() throws Exception {
        // CPF digitado errado no AD não pode entregar a conta de outra pessoa.
        String cpf = CpfTestFactory.next();
        AppUser conta = contaLocal("pessoal." + UUID.randomUUID() + "@gmail.com", true);
        Student aluno = new Student();
        aluno.setFullName("Maria Aparecida Souza");
        aluno.setCpf(cpf);
        aluno.setUserId(conta.getId());
        students.save(aluno);
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, emailGov(), "Josias Silva Siqueira", cpf)));

        login(sam, "senha-do-governo").andExpect(status().isUnprocessableEntity());

        assertThat(users.findById(conta.getId()).orElseThrow().getLdapGuid()).isNull();
    }

    /** Migrado da base antiga: login com o e-mail pessoal, institucional só no
     *  contato do aluno e sem CPF no AD — vincula pelo e-mail de contato. */
    @Test
    void vinculaPeloEmailDeContatoDoAlunoQuandoOLoginUsaEmailPessoal() throws Exception {
        AppUser conta = contaLocal("pessoal." + UUID.randomUUID() + "@gmail.com", true);
        String emailGov = emailGov();
        Student aluno = new Student();
        aluno.setFullName("Fulana Rocha Silva");
        aluno.setCpf(CpfTestFactory.next());
        aluno.setEmail(emailGov);
        aluno.setUserId(conta.getId());
        students.save(aluno);
        UUID guid = UUID.randomUUID();
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(guid, sam, emailGov.toUpperCase(), "Fulana Rocha Silva", null)));

        login(sam, "senha-do-governo").andExpect(status().isOk()).andExpect(jsonPath("$.accessToken").exists());

        assertThat(users.findById(conta.getId()).orElseThrow().getLdapGuid()).isEqualTo(guid);
    }

    /** Caso real: no AD o mail é johnathan-ps@ e o UPN johnathan.sousa@; o
     *  contato do aluno estava com o UPN. */
    @Test
    void vinculaPeloUpnQuandoOMailDoAdEDiferenteDoContato() throws Exception {
        AppUser conta = contaLocal("pessoal." + UUID.randomUUID() + "@gmail.com", true);
        String upn = "ad.upn." + UUID.randomUUID() + "@goias.gov.br";
        Student aluno = new Student();
        aluno.setFullName("Johnathan Pereira de Sousa");
        aluno.setCpf(CpfTestFactory.next());
        aluno.setEmail(upn);
        aluno.setUserId(conta.getId());
        students.save(aluno);
        UUID guid = UUID.randomUUID();
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(guid, sam, "outro-mail." + UUID.randomUUID() + "@goias.gov.br",
                        "Johnathan Pereira de Sousa", null, upn)));

        login(sam, "senha-do-governo").andExpect(status().isOk());

        assertThat(users.findById(conta.getId()).orElseThrow().getLdapGuid()).isEqualTo(guid);
    }

    @Test
    void recusaVinculoPorEmailDeContatoQuandoOPrimeiroNomeNaoBate() throws Exception {
        AppUser conta = contaLocal("pessoal." + UUID.randomUUID() + "@gmail.com", true);
        String emailGov = emailGov();
        Student aluno = new Student();
        aluno.setFullName("Maria Aparecida Souza");
        aluno.setCpf(CpfTestFactory.next());
        aluno.setEmail(emailGov);
        aluno.setUserId(conta.getId());
        students.save(aluno);
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, emailGov, "Josias Silva Siqueira", null)));

        login(sam, "senha-do-governo").andExpect(status().isUnprocessableEntity());

        assertThat(users.findById(conta.getId()).orElseThrow().getLdapGuid()).isNull();
    }

    @Test
    void emailDeContatoRepetidoEmDoisAlunosNaoVinculaNinguem() throws Exception {
        String emailGov = emailGov();
        AppUser contaA = contaLocal("pessoal." + UUID.randomUUID() + "@gmail.com", true);
        AppUser contaB = contaLocal("pessoal." + UUID.randomUUID() + "@gmail.com", true);
        for (AppUser conta : java.util.List.of(contaA, contaB)) {
            Student aluno = new Student();
            aluno.setFullName("Ana Souza " + UUID.randomUUID());
            aluno.setCpf(CpfTestFactory.next());
            aluno.setEmail(emailGov);
            aluno.setUserId(conta.getId());
            students.save(aluno);
        }
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, emailGov, "Ana Souza", null)));

        login(sam, "senha-do-governo").andExpect(status().isUnprocessableEntity());

        assertThat(users.findById(contaA.getId()).orElseThrow().getLdapGuid()).isNull();
        assertThat(users.findById(contaB.getId()).orElseThrow().getLdapGuid()).isNull();
    }

    @Test
    void primeiroNomeComparaSemAcentoNemCaixa() {
        assertThat(LdapAuthProvider.mesmoPrimeiroNome("JOSÉ da Silva", "Jose Pereira")).isTrue();
        assertThat(LdapAuthProvider.mesmoPrimeiroNome("José", "João")).isFalse();
        assertThat(LdapAuthProvider.mesmoPrimeiroNome(null, "José")).isFalse();
    }

    @Test
    void credencialValidaNoAdSemContaLocalRecebeMensagemEspecifica() throws Exception {
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, emailGov(), "Sem Cadastro", null)));

        login(sam, "senha-do-governo").andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("não encontramos uma conta")));
    }

    @Test
    void contaLocalJaVinculadaAOutraIdentidadeDoAdERecusada() throws Exception {
        String email = emailGov();
        AppUser conta = contaLocal(email, true);
        conta.setLdapGuid(UUID.randomUUID());
        users.save(conta);
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, email, "Outro Fulano", null)));

        login(sam, "senha-do-governo").andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("outra identidade")));
    }

    @Test
    void contaPendenteDeAprovacaoContinuaBloqueadaMesmoComSenhaDoGoverno() throws Exception {
        String email = emailGov();
        AppUser conta = contaLocal(email, false);
        Student aluno = new Student();
        aluno.setFullName("Aluno Pendente");
        aluno.setCpf(CpfTestFactory.next());
        aluno.setUserId(conta.getId());
        aluno.setStatusCadastro(Student.STATUS_PENDENTE);
        students.save(aluno);
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, email, "Aluno Pendente", null)));

        login(sam, "senha-do-governo").andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("análise")));
    }

    @Test
    void senhaLocalValidaNemConsultaOAd() throws Exception {
        String email = emailGov();
        contaLocal(email, true);

        login(email, "senha-local-123").andExpect(status().isOk());

        verify(directory, never()).authenticate(anyString(), anyString());
    }

    @Test
    void usuarioInexistenteNoAdDaMensagemGenericaDeCredencialInvalida() throws Exception {
        String sam = sam();
        when(directory.authenticate(sam, "qualquer")).thenReturn(LdapAuthResult.naoEncontrado());

        login(sam, "qualquer").andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("inválidos")));
    }

    @Test
    void bloqueiaNovasTentativasDepoisDeVariasSenhasErradasSemTocarNoAd() throws Exception {
        // Protege a conta real da pessoa no AD contra bloqueio por tentativas via nosso login.
        String sam = sam();
        when(directory.authenticate(sam, "errada")).thenReturn(LdapAuthResult.senhaInvalida());

        for (int i = 0; i < 4; i++) {
            login(sam, "errada").andExpect(status().isUnprocessableEntity())
                    .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("inválidos")));
        }
        login(sam, "errada").andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Muitas tentativas")));

        verify(directory, times(4)).authenticate(sam, "errada"); // a 5ª nem chegou ao AD
    }

    @Test
    void adForaDoArDaMensagemClaraEmVezDeErro500() throws Exception {
        String sam = sam();
        when(directory.authenticate(sam, "senha")).thenThrow(new LdapUnavailableException("timeout", null));

        login(sam, "senha").andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("Tente de novo")));
    }

    @Test
    void cadaLoginPeloAdAtualizaOEmailDeContatoDoAlunoMasNaoOEmailDeLogin() throws Exception {
        String cpf = CpfTestFactory.next();
        String emailLogin = "pessoal." + UUID.randomUUID() + "@gmail.com";
        AppUser conta = contaLocal(emailLogin, true);
        Student aluno = new Student();
        aluno.setFullName("Josias Silva Siqueira");
        aluno.setCpf(cpf);
        aluno.setEmail(emailLogin);
        aluno.setUserId(conta.getId());
        students.save(aluno);
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, "Josias.Novo@goias.gov.br", "Josias Silva Siqueira", cpf)));

        login(sam, "senha-do-governo").andExpect(status().isOk());

        assertThat(students.findById(aluno.getId()).orElseThrow().getEmail()).isEqualTo("josias.novo@goias.gov.br");
        assertThat(users.findById(conta.getId()).orElseThrow().getEmail()).isEqualTo(emailLogin); // login intacto
    }

    @Test
    void emailDoAdForaDoDominioInstitucionalNaoSobrescreveOContatoDoAluno() throws Exception {
        AppUser conta = contaLocal(emailGov(), true);
        UUID guid = UUID.randomUUID();
        conta.setLdapGuid(guid);
        users.save(conta);
        Student aluno = new Student();
        aluno.setFullName("Maria Souza");
        aluno.setCpf(CpfTestFactory.next());
        aluno.setEmail("contato@gmail.com");
        aluno.setUserId(conta.getId());
        students.save(aluno);
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(guid, sam, "maria@externo.com", "Maria Souza", null)));

        login(sam, "senha-do-governo").andExpect(status().isOk());

        assertThat(students.findById(aluno.getId()).orElseThrow().getEmail()).isEqualTo("contato@gmail.com");
    }

    /** Cadastro público sem senha (o formulário não pede mais): depois de
     *  aprovado, a pessoa entra só com a conta do governo — a senha local
     *  não existe. */
    @Test
    void cadastroSemSenha_entraSoPelaContaDoGoverno() throws Exception {
        String email = emailGov();
        ObjectNode dados = objectMapper.createObjectNode();
        dados.put("fullName", "Servidora Sem Senha");
        dados.put("cpf", br.gov.goias.secami.academy.cadastros.CpfTestFactory.next());
        dados.put("birthDate", "1990-01-01");
        dados.put("whatsapp", "62999990000");
        dados.put("departmentId", departamento().toString());
        dados.put("email", email);
        ObjectNode parQ = dados.putObject("parQ");
        for (String pergunta : br.gov.goias.secami.registration.RegistrationService.PAR_Q_PERGUNTAS) {
            parQ.put(pergunta, false);
        }
        dados.put("termoResponsabilidade", true);
        dados.put("termoCiencia", true);
        dados.put("medicoNome", "Dr. Teste");
        dados.put("medicoCrm", "1234");
        dados.put("medicoCrmUf", "GO");
        dados.put("atestadoEmissaoData", java.time.LocalDate.now().toString());
        var dadosPart = new org.springframework.mock.web.MockMultipartFile(
                "dados", "", "application/json", objectMapper.writeValueAsBytes(dados));
        var atestado = new org.springframework.mock.web.MockMultipartFile(
                "atestado", "atestado.pdf", "application/pdf", "%PDF-1.4\n%%EOF".getBytes());
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .multipart("/cadastro").file(dadosPart).file(atestado))
                .andExpect(status().isCreated());

        AppUser conta = users.findByEmailIgnoreCase(email).orElseThrow();
        assertThat(conta.getPasswordHash()).isNull();
        Student aluno = students.findByUserId(conta.getId()).orElseThrow();
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .post("/admin/cadastros/" + aluno.getId() + "/aprovar")
                        .header("Authorization", "Bearer " + loginAs("admin"))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"studentType\":\"Civil\"}"))
                .andExpect(status().isOk());

        // Sem senha local: e-mail + qualquer senha não entra.
        when(directory.authenticate(anyString(), anyString())).thenReturn(LdapAuthResult.naoEncontrado());
        login(email, "qualquer-senha-123").andExpect(status().isUnprocessableEntity());

        // Pela conta do governo, vinculada pelo e-mail institucional, entra.
        String sam = sam();
        when(directory.authenticate(sam, "senha-do-governo")).thenReturn(LdapAuthResult.autenticado(
                new LdapUser(UUID.randomUUID(), sam, email, "Servidora Sem Senha", null)));
        login(sam, "senha-do-governo").andExpect(status().isOk()).andExpect(jsonPath("$.accessToken").exists());
    }

    private UUID departamento() {
        return departments.findAll().stream().findFirst().orElseGet(() -> {
            var d = new br.gov.goias.secami.academy.department.Department();
            d.setName("Secretaria Teste " + UUID.randomUUID());
            return departments.save(d);
        }).getId();
    }
}
