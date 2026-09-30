package br.gov.goias.secami.academy.cadastros;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** POST /admin/alunos/atualizar-emails — e-mail de contato em lote, casando por CPF. */
class StudentEmailUpdateTest extends AbstractIntegrationTest {

    @Autowired StudentRepository students;
    @Autowired AppUserRepository users;

    private Student aluno(String cpf, String email) {
        Student s = new Student();
        s.setFullName("Aluno E-mail " + UUID.randomUUID());
        s.setCpf(cpf);
        s.setEmail(email);
        return students.save(s);
    }

    private String email(Student s) {
        return students.findById(s.getId()).orElseThrow().getEmail();
    }

    private org.springframework.test.web.servlet.ResultActions enviar(String corpo, boolean simular)
            throws Exception {
        return mockMvc.perform(authed(post("/admin/alunos/atualizar-emails?simular=" + simular), loginAs("admin"))
                .contentType(MediaType.APPLICATION_JSON).content(corpo));
    }

    @Test
    void atualizaOContatoPeloCpf_semMexerNoEmailDeLogin() throws Exception {
        String cpf = CpfTestFactory.next();
        AppUser u = new AppUser();
        u.setNome("Login Pessoal");
        u.setEmail("login." + UUID.randomUUID() + "@gmail.com");
        u.setTipoIdentidade("local");
        u.getRoles().add(Roles.ALUNO);
        u = users.save(u);
        Student s = aluno(cpf, u.getEmail());
        s.setUserId(u.getId());
        students.save(s);

        // CPF com máscara e e-mail em maiúsculas: normaliza os dois.
        String mascarado = cpf.substring(0, 3) + "." + cpf.substring(3, 6) + "." + cpf.substring(6, 9)
                + "-" + cpf.substring(9);
        enviar("[{\"cpf\":\"" + mascarado + "\",\"email\":\" Fulano.Silva@GOIAS.gov.br \"}]", false)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.atualizados").value(1));

        assertThat(email(s)).isEqualTo("fulano.silva@goias.gov.br");
        assertThat(users.findById(u.getId()).orElseThrow().getEmail()).isEqualTo(u.getEmail());
    }

    @Test
    void simulacaoPorPadrao_naoGrava() throws Exception {
        String cpf = CpfTestFactory.next();
        Student s = aluno(cpf, "antigo@gmail.com");

        mockMvc.perform(authed(post("/admin/alunos/atualizar-emails"), loginAs("admin"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("[{\"cpf\":\"" + cpf + "\",\"email\":\"novo@goias.gov.br\"}]"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.simulacao").value(true))
                .andExpect(jsonPath("$.atualizados").value(1));

        students.flush();
        assertThat(email(s)).isEqualTo("antigo@gmail.com");
    }

    @Test
    void recusaOQueNaoEConfiavel_eRelataCadaCaso() throws Exception {
        String cpfTypo = CpfTestFactory.next(), cpfGov = CpfTestFactory.next(), cpfMalFormatado = CpfTestFactory.next();
        Student typo = aluno(cpfTypo, "a@gmail.com");
        Student gov = aluno(cpfGov, "servidor@goias.gov.br");
        Student malFormatado = aluno(cpfMalFormatado, "b@gmail.com");
        String semAluno = CpfTestFactory.next();

        String corpo = "["
                + "{\"cpf\":\"" + cpfTypo + "\",\"email\":\"fulano@goiad.gov.br\"},"          // erro de digitação
                + "{\"cpf\":\"" + cpfGov + "\",\"email\":\"servidor@gmail.com\"},"            // rebaixaria gov → pessoal
                + "{\"cpf\":\"" + cpfMalFormatado + "\",\"email\":\"sem-arroba\"},"
                + "{\"cpf\":\"12345678900\",\"email\":\"x@goias.gov.br\"},"                   // CPF inválido
                + "{\"cpf\":\"" + semAluno + "\",\"email\":\"y@goias.gov.br\"}"               // CPF sem aluno
                + "]";
        enviar(corpo, false)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.atualizados").value(0))
                .andExpect(jsonPath("$.suspeitos").value(1))
                .andExpect(jsonPath("$.mantidos").value(1))
                .andExpect(jsonPath("$.emailInvalidos").value(1))
                .andExpect(jsonPath("$.cpfInvalidos").value(1))
                .andExpect(jsonPath("$.naoEncontrados").value(1))
                .andExpect(jsonPath("$.ocorrencias.length()").value(5))
                // CPF nunca volta inteiro na resposta.
                .andExpect(jsonPath("$.ocorrencias[?(@.cpf == '" + cpfTypo + "')]").isEmpty());

        assertThat(email(typo)).isEqualTo("a@gmail.com");
        assertThat(email(gov)).isEqualTo("servidor@goias.gov.br");
        assertThat(email(malFormatado)).isEqualTo("b@gmail.com");
    }

    @Test
    void aceitaSubdominioDoGoverno_eUltimaRespostaDoMesmoCpfVale() throws Exception {
        String cpf = CpfTestFactory.next();
        Student s = aluno(cpf, "antigo@goias.gov.br");

        enviar("[{\"cpf\":\"" + cpf + "\",\"email\":\"primeira@goias.gov.br\"},"
                + "{\"cpf\":\"" + cpf + "\",\"email\":\"terceirizado@fornecedores.goias.gov.br\"}]", false)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.recebidos").value(2))
                .andExpect(jsonPath("$.cpfsDistintos").value(1))
                .andExpect(jsonPath("$.atualizados").value(1));

        assertThat(email(s)).isEqualTo("terceirizado@fornecedores.goias.gov.br");
    }

    @Test
    void corrigeAcentoEPontoSobrando_masNaoEspacoNoMeio() throws Exception {
        String cpfAcento = CpfTestFactory.next(), cpfPonto = CpfTestFactory.next(), cpfEspaco = CpfTestFactory.next();
        Student acento = aluno(cpfAcento, "a@gmail.com");
        Student ponto = aluno(cpfPonto, "b@gmail.com");
        Student espaco = aluno(cpfEspaco, "c@gmail.com");

        enviar("[{\"cpf\":\"" + cpfAcento + "\",\"email\":\"João.Conceição@goias.gov.br\"},"
                + "{\"cpf\":\"" + cpfPonto + "\",\"email\":\"maria@.goias.gov.br\"},"
                + "{\"cpf\":\"" + cpfEspaco + "\",\"email\":\"jose silva@goias.gov.br\"}]", false)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.atualizados").value(2))
                .andExpect(jsonPath("$.corrigidos").value(2))
                .andExpect(jsonPath("$.emailInvalidos").value(1));

        assertThat(email(acento)).isEqualTo("joao.conceicao@goias.gov.br");
        assertThat(email(ponto)).isEqualTo("maria@goias.gov.br");
        assertThat(email(espaco)).isEqualTo("c@gmail.com");
    }

    /** Planilha guarda CPF como número e perde o zero à esquerda. */
    @Test
    void cpfSemZeroAEsquerda_eCompletado() throws Exception {
        Student s = aluno("01234567890", "antigo@gmail.com"); // 012.345.678-90 é um CPF válido
        enviar("[{\"cpf\":\"1234567890\",\"email\":\"novo@goias.gov.br\"}]", false)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.atualizados").value(1));
        assertThat(email(s)).isEqualTo("novo@goias.gov.br");
    }

    @Test
    void soAdminPodeRodar() throws Exception {
        mockMvc.perform(authed(post("/admin/alunos/atualizar-emails"), loginAs("recepcao"))
                        .contentType(MediaType.APPLICATION_JSON).content("[]"))
                .andExpect(status().isForbidden());
    }
}
