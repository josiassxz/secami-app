package br.gov.goias.secami.auth.ldap;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.ResultActions;

import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Admin troca o e-mail do aluno na edição: como o e-mail de contato é o que
 * liga o login pelo governo à conta da academia, ele só é gravado se existir
 * no AD e for da mesma pessoa.
 */
@TestPropertySource(properties = "secami.ldap.enabled=true")
class EdicaoEmailNoAdTest extends AbstractIntegrationTest {

    @Autowired private StudentRepository students;
    @MockBean private LdapDirectory directory;

    private Student aluno(String nome, String email) {
        Student s = new Student();
        s.setFullName(nome);
        s.setCpf(CpfTestFactory.next());
        s.setEmail(email);
        return students.save(s);
    }

    private ResultActions editar(Student s, String email) throws Exception {
        return mockMvc.perform(put("/students/" + s.getId())
                .header("Authorization", "Bearer " + loginAs("admin"))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(Map.of(
                        "fullName", s.getFullName(), "cpf", s.getCpf(), "studentType", "Civil", "email", email))));
    }

    private static String emailGov() { return "ad." + UUID.randomUUID() + "@fornecedores.goias.gov.br"; }

    @Test
    void gravaOEmailQuandoExisteNoAdEEDaMesmaPessoa() throws Exception {
        Student s = aluno("Samuel Souza Costa", "pessoal@gmail.com");
        String novo = emailGov();
        when(directory.buscarPorEmail(novo)).thenReturn(Optional.of(
                new LdapUser(UUID.randomUUID(), "samuel.scosta", novo, "Samuel Souza Costa", null)));

        editar(s, novo.toUpperCase()).andExpect(status().isOk());

        assertThat(students.findById(s.getId()).orElseThrow().getEmail()).isEqualTo(novo);
    }

    @Test
    void recusaQuandoOEmailNaoExisteNoAd() throws Exception {
        Student s = aluno("Samuel Souza Costa", "pessoal@gmail.com");
        String novo = emailGov();
        when(directory.buscarPorEmail(novo)).thenReturn(Optional.empty());

        editar(s, novo).andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("esse usuário não existe no AD")));

        assertThat(students.findById(s.getId()).orElseThrow().getEmail()).isEqualTo("pessoal@gmail.com");
    }

    @Test
    void recusaQuandoNoAdOEmailEDeOutraPessoa() throws Exception {
        Student s = aluno("Samuel Souza Costa", "pessoal@gmail.com");
        String novo = emailGov();
        when(directory.buscarPorEmail(novo)).thenReturn(Optional.of(
                new LdapUser(UUID.randomUUID(), "maria.souza", novo, "Maria Souza", null)));

        editar(s, novo).andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("pertence a Maria Souza")));
    }

    @Test
    void recusaEmailQueJaEstaNoCadastroDeOutroAluno() throws Exception {
        String novo = emailGov();
        aluno("Samuel Outro", novo);
        Student s = aluno("Samuel Souza Costa", "pessoal@gmail.com");
        when(directory.buscarPorEmail(novo)).thenReturn(Optional.of(
                new LdapUser(UUID.randomUUID(), "samuel.scosta", novo, "Samuel Souza Costa", null)));

        editar(s, novo).andExpect(status().isConflict());
    }

    @Test
    void editarSemTrocarOEmailNaoConsultaOAd() throws Exception {
        Student s = aluno("Aluno Antigo", "pessoal@gmail.com");

        editar(s, "pessoal@gmail.com").andExpect(status().isOk());

        verify(directory, never()).buscarPorEmail(anyString());
    }

    @Test
    void adForaDoArDaMensagemClara() throws Exception {
        Student s = aluno("Samuel Souza Costa", "pessoal@gmail.com");
        String novo = emailGov();
        when(directory.buscarPorEmail(novo)).thenThrow(new LdapUnavailableException("timeout", null));

        editar(s, novo).andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("Tente de novo")));
    }
}
