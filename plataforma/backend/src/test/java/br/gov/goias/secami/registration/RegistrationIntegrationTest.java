package br.gov.goias.secami.registration;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.department.Department;
import br.gov.goias.secami.academy.department.DepartmentRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Cadastro público (formulário "ACADEMIA ESPAÇO SAÚDE"): submissão com
 * PAR-Q + atestado em PDF, fila de aprovação do admin, e o login
 * bloqueado/liberado conforme o status. Banco isolado: secami_test_reg.
 */
class RegistrationIntegrationTest extends AbstractIntegrationTest {

    @Autowired DepartmentRepository departments;
    @Autowired AppUserRepository users;
    @Autowired PasswordEncoder encoder;
    @Autowired StudentRepository students;

    /** PDF mínimo válido (cabeçalho %PDF- + EOF) — o service só confere content-type. */
    private static final byte[] PDF_BYTES = "%PDF-1.4\n%%EOF".getBytes();

    private UUID umDepartamento() {
        Department d = departments.findAll().stream().findFirst().orElseGet(() -> {
            Department novo = new Department();
            novo.setName("Secretaria de Teste " + UUID.randomUUID());
            return departments.save(novo);
        });
        return d.getId();
    }

    private ObjectNode dadosValidos(String email, String cpf) {
        ObjectNode n = objectMapper.createObjectNode();
        n.put("fullName", "Aluno Cadastro Teste");
        n.put("cpf", cpf);
        n.put("birthDate", "1996-04-09");
        n.put("whatsapp", "62981039144");
        n.put("departmentId", umDepartamento().toString());
        n.put("email", email);
        n.put("password", "senha12345");
        n.put("weightKg", 78.5);
        n.put("heightCm", 178);
        n.putArray("objetivos").add("Hipertrofia").add("Condicionamento");
        ObjectNode parQ = n.putObject("parQ");
        for (String pergunta : RegistrationService.PAR_Q_PERGUNTAS) {
            parQ.put(pergunta, false);
        }
        n.put("termoResponsabilidade", true);
        n.put("termoCiencia", true);
        n.put("medicoNome", "Dr. Fulano de Tal");
        n.put("medicoCrm", "123456");
        n.put("medicoCrmUf", "GO");
        n.put("atestadoEmissaoData", "2026-08-01");
        return n;
    }

    private org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder
    cadastroRequest(ObjectNode dados) throws Exception {
        MockMultipartFile dadosPart = new MockMultipartFile(
                "dados", "", "application/json", objectMapper.writeValueAsBytes(dados));
        MockMultipartFile atestadoPart = new MockMultipartFile(
                "atestado", "atestado.pdf", "application/pdf", PDF_BYTES);
        return multipart("/cadastro").file(dadosPart).file(atestadoPart);
    }

    @Test
    void cadastroValido_criaAlunoPendenteSemPrecisarDeToken() throws Exception {
        String email = "novo.aluno." + UUID.randomUUID() + "@goias.gov.br";
        mockMvc.perform(cadastroRequest(dadosValidos(email, CpfTestFactory.next())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("pendente"));

        assertThat(users.findByEmailIgnoreCase(email)).isPresent();
        assertThat(users.findByEmailIgnoreCase(email).get().isAtivo()).isFalse();
    }

    @Test
    void cadastroSemArquivoPdf_retorna422() throws Exception {
        MockMultipartFile dadosPart = new MockMultipartFile(
                "dados", "", "application/json",
                objectMapper.writeValueAsBytes(dadosValidos("sem.atestado@goias.gov.br", CpfTestFactory.next())));
        // Sem o part "atestado" -> Spring já rejeita como 400 (part obrigatório ausente).
        mockMvc.perform(multipart("/cadastro").file(dadosPart))
                .andExpect(status().is4xxClientError());
    }

    @Test
    void cadastroComParQIncompleto_retorna422() throws Exception {
        ObjectNode dados = dadosValidos("parq.incompleto@goias.gov.br", CpfTestFactory.next());
        ((ObjectNode) dados.get("parQ")).remove("problema_coracao");
        mockMvc.perform(cadastroRequest(dados))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void cadastroSemAceitarTermos_retorna400() throws Exception {
        ObjectNode dados = dadosValidos("sem.termo@goias.gov.br", CpfTestFactory.next());
        dados.put("termoCiencia", false);
        mockMvc.perform(cadastroRequest(dados))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cadastroComEmailForaDoDominioGoias_retorna400() throws Exception {
        ObjectNode dados = dadosValidos("fora.do.dominio@gmail.com", CpfTestFactory.next());
        mockMvc.perform(cadastroRequest(dados))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cadastroComEmailJaExistente_retorna409() throws Exception {
        String email = "duplicado." + UUID.randomUUID() + "@goias.gov.br";
        mockMvc.perform(cadastroRequest(dadosValidos(email, CpfTestFactory.next())))
                .andExpect(status().isCreated());
        mockMvc.perform(cadastroRequest(dadosValidos(email, CpfTestFactory.next())))
                .andExpect(status().isConflict());
    }

    @Test
    void cadastroComCpfJaExistente_retorna409() throws Exception {
        String cpf = CpfTestFactory.next();
        mockMvc.perform(cadastroRequest(dadosValidos("cpf1." + UUID.randomUUID() + "@goias.gov.br", cpf)))
                .andExpect(status().isCreated());
        mockMvc.perform(cadastroRequest(dadosValidos("cpf2." + UUID.randomUUID() + "@goias.gov.br", cpf)))
                .andExpect(status().isConflict());
    }

    @Test
    void loginComCadastroPendente_bloqueiaComMensagemDeAnalise() throws Exception {
        String email = "pendente." + UUID.randomUUID() + "@goias.gov.br";
        mockMvc.perform(cadastroRequest(dadosValidos(email, CpfTestFactory.next())))
                .andExpect(status().isCreated());

        mockMvc.perform(post("/auth/login")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"senha12345\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("análise")));
    }

    @Test
    void fluxoCompleto_pendenteApareceNaFila_aprovaLiberaLogin_rejeitaBloqueiaComMotivo() throws Exception {
        String emailAprovado = "aprovado." + UUID.randomUUID() + "@goias.gov.br";
        String emailRejeitado = "rejeitado." + UUID.randomUUID() + "@goias.gov.br";
        mockMvc.perform(cadastroRequest(dadosValidos(emailAprovado, CpfTestFactory.next())))
                .andExpect(status().isCreated());
        mockMvc.perform(cadastroRequest(dadosValidos(emailRejeitado, CpfTestFactory.next())))
                .andExpect(status().isCreated());

        String tokenAdmin = loginAs("admin");

        String pendentesJson = mockMvc.perform(authed(get("/admin/cadastros/pendentes"), tokenAdmin))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        var pendentes = objectMapper.readTree(pendentesJson);
        UUID idAprovado = null, idRejeitado = null;
        for (var node : pendentes) {
            if (node.get("email").asText().equals(emailAprovado)) idAprovado = UUID.fromString(node.get("studentId").asText());
            if (node.get("email").asText().equals(emailRejeitado)) idRejeitado = UUID.fromString(node.get("studentId").asText());
        }
        assertThat(idAprovado).isNotNull();
        assertThat(idRejeitado).isNotNull();

        mockMvc.perform(authed(post("/admin/cadastros/" + idAprovado + "/aprovar"), tokenAdmin)
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"studentType\":\"Militar\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.studentType").value("Militar"));
        mockMvc.perform(authed(post("/admin/cadastros/" + idRejeitado + "/rejeitar"), tokenAdmin)
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"motivo\":\"CRM inválido\"}"))
                .andExpect(status().isOk());

        // Aprovado: login funciona.
        mockMvc.perform(post("/auth/login")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + emailAprovado + "\",\"password\":\"senha12345\"}"))
                .andExpect(status().isOk());

        // Rejeitado: login continua bloqueado, com o motivo na mensagem.
        mockMvc.perform(post("/auth/login")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + emailRejeitado + "\",\"password\":\"senha12345\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(org.hamcrest.Matchers.containsString("CRM inválido")));
    }

    @Test
    void aprovarComCategoriaInvalida_retorna422() throws Exception {
        String email = "categoria.invalida." + UUID.randomUUID() + "@goias.gov.br";
        mockMvc.perform(cadastroRequest(dadosValidos(email, CpfTestFactory.next())))
                .andExpect(status().isCreated());
        String tokenAdmin = loginAs("admin");
        String pendentesJson = mockMvc.perform(authed(get("/admin/cadastros/pendentes"), tokenAdmin))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        UUID id = null;
        for (var node : objectMapper.readTree(pendentesJson)) {
            if (node.get("email").asText().equals(email)) id = UUID.fromString(node.get("studentId").asText());
        }
        assertThat(id).isNotNull();

        mockMvc.perform(authed(post("/admin/cadastros/" + id + "/aprovar"), tokenAdmin)
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"studentType\":\"Alienígena\"}"))
                .andExpect(status().isUnprocessableEntity());

        mockMvc.perform(authed(post("/admin/cadastros/" + id + "/aprovar"), tokenAdmin)
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"studentType\":\"\"}"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void filaDeAprovacao_bloqueiaParaQuemNaoEAdminOuGerente() throws Exception {
        String tokenAluno = loginAs("aluno");
        mockMvc.perform(authed(get("/admin/cadastros/pendentes"), tokenAluno))
                .andExpect(status().isForbidden());
    }

    /** Simula um aluno migrado do legado (base44): tem Student com legacyId,
     *  mas nunca teve AppUser/login — igual aos 565 alunos migrados em prod. */
    private Student alunoMigrado(String fullName, String email) {
        Student s = new Student();
        s.setFullName(fullName);
        s.setEmail(email);
        s.setLegacyId("legado-" + UUID.randomUUID());
        return students.save(s);
    }

    @Test
    void criarAcessosEmMassa_provisionaLoginComEmailDaMigracaoESenhaPadraoDoPrimeiroNome() throws Exception {
        String email1 = "joao.migrado." + UUID.randomUUID() + "@gmail.com";
        String email2 = "jose.migrado." + UUID.randomUUID() + "@gmail.com";
        Student s1 = alunoMigrado("joão pedro da silva", email1);
        Student s2 = alunoMigrado("José Eduardo", email2);

        String tokenAdmin = loginAs("admin");
        String responseJson = mockMvc.perform(authed(post("/admin/alunos/criar-acessos-em-massa"), tokenAdmin))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        var response = objectMapper.readTree(responseJson);

        Map<String, String> senhasPorEmail = new java.util.HashMap<>();
        for (var node : response.get("criados")) {
            senhasPorEmail.put(node.get("email").asText(), node.get("senhaGerada").asText());
        }
        assertThat(senhasPorEmail).containsEntry(email1, "Joao@123");
        assertThat(senhasPorEmail).containsEntry(email2, "Jose@123");

        // Login funciona de verdade com a senha gerada.
        mockMvc.perform(post("/auth/login")
                        .contentType(org.springframework.http.MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email1 + "\",\"password\":\"Joao@123\"}"))
                .andExpect(status().isOk());

        assertThat(students.findByIdAndDeletedAtIsNull(s1.getId()).orElseThrow().getUserId()).isNotNull();
        assertThat(students.findByIdAndDeletedAtIsNull(s2.getId()).orElseThrow().getUserId()).isNotNull();
    }

    @Test
    void criarAcessosEmMassa_pulaAlunoSemEmailEAlunoComEmailJaEmUso() throws Exception {
        alunoMigrado("Aluno Sem Email", null);

        String emailDuplicado = "ja.tem.conta." + UUID.randomUUID() + "@gmail.com";
        AppUser existente = new AppUser();
        existente.setNome("Já Tem Conta");
        existente.setEmail(emailDuplicado);
        existente.setTipoIdentidade("local");
        existente.setAtivo(true);
        existente.setPasswordHash(encoder.encode("qualquer12345"));
        existente.getRoles().add(Roles.ALUNO);
        users.save(existente);
        alunoMigrado("Já Tem Conta", emailDuplicado);

        String tokenAdmin = loginAs("admin");
        String responseJson = mockMvc.perform(authed(post("/admin/alunos/criar-acessos-em-massa"), tokenAdmin))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        var response = objectMapper.readTree(responseJson);

        var motivos = new java.util.ArrayList<String>();
        for (var node : response.get("pulados")) motivos.add(node.get("motivo").asText());
        assertThat(motivos).anyMatch(m -> m.contains("sem e-mail"));
        assertThat(motivos).anyMatch(m -> m.contains("já existe uma conta"));
    }

    @Test
    void criarAcessosEmMassa_bloqueiaParaQuemNaoEAdminOuGerente() throws Exception {
        String tokenAluno = loginAs("aluno");
        mockMvc.perform(authed(post("/admin/alunos/criar-acessos-em-massa"), tokenAluno))
                .andExpect(status().isForbidden());
    }
}
