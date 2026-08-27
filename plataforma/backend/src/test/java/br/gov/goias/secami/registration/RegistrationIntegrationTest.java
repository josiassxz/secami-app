package br.gov.goias.secami.registration;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.department.Department;
import br.gov.goias.secami.academy.department.DepartmentRepository;
import br.gov.goias.secami.identity.AppUserRepository;
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
        n.put("studentType", "Civil");
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
        String email = "novo.aluno." + UUID.randomUUID() + "@example.com";
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
                objectMapper.writeValueAsBytes(dadosValidos("sem.atestado@example.com", CpfTestFactory.next())));
        // Sem o part "atestado" -> Spring já rejeita como 400 (part obrigatório ausente).
        mockMvc.perform(multipart("/cadastro").file(dadosPart))
                .andExpect(status().is4xxClientError());
    }

    @Test
    void cadastroComParQIncompleto_retorna422() throws Exception {
        ObjectNode dados = dadosValidos("parq.incompleto@example.com", CpfTestFactory.next());
        ((ObjectNode) dados.get("parQ")).remove("problema_coracao");
        mockMvc.perform(cadastroRequest(dados))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void cadastroSemAceitarTermos_retorna400() throws Exception {
        ObjectNode dados = dadosValidos("sem.termo@example.com", CpfTestFactory.next());
        dados.put("termoCiencia", false);
        mockMvc.perform(cadastroRequest(dados))
                .andExpect(status().isBadRequest());
    }

    @Test
    void cadastroComEmailJaExistente_retorna409() throws Exception {
        String email = "duplicado." + UUID.randomUUID() + "@example.com";
        mockMvc.perform(cadastroRequest(dadosValidos(email, CpfTestFactory.next())))
                .andExpect(status().isCreated());
        mockMvc.perform(cadastroRequest(dadosValidos(email, CpfTestFactory.next())))
                .andExpect(status().isConflict());
    }

    @Test
    void cadastroComCpfJaExistente_retorna409() throws Exception {
        String cpf = CpfTestFactory.next();
        mockMvc.perform(cadastroRequest(dadosValidos("cpf1." + UUID.randomUUID() + "@example.com", cpf)))
                .andExpect(status().isCreated());
        mockMvc.perform(cadastroRequest(dadosValidos("cpf2." + UUID.randomUUID() + "@example.com", cpf)))
                .andExpect(status().isConflict());
    }

    @Test
    void loginComCadastroPendente_bloqueiaComMensagemDeAnalise() throws Exception {
        String email = "pendente." + UUID.randomUUID() + "@example.com";
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
        String emailAprovado = "aprovado." + UUID.randomUUID() + "@example.com";
        String emailRejeitado = "rejeitado." + UUID.randomUUID() + "@example.com";
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

        mockMvc.perform(authed(post("/admin/cadastros/" + idAprovado + "/aprovar"), tokenAdmin))
                .andExpect(status().isOk());
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
    void filaDeAprovacao_bloqueiaParaQuemNaoEAdminOuGerente() throws Exception {
        String tokenAluno = loginAs("aluno");
        mockMvc.perform(authed(get("/admin/cadastros/pendentes"), tokenAluno))
                .andExpect(status().isForbidden());
    }
}
