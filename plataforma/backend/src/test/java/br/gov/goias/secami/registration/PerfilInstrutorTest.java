package br.gov.goias.secami.registration;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import com.fasterxml.jackson.databind.JsonNode;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDate;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.containsString;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Perfil "Instrutor": o admin escolhe o perfil ao aprovar o cadastro (ou ao
 * editar o tipo depois). Instrutor fica com o papel {@code professor} no lugar
 * de {@code aluno}: prescreve fichas pros alunos e não faz agendamento.
 */
class PerfilInstrutorTest extends AbstractIntegrationTest {

    private static final String SENHA = "senha12345";

    @Autowired AppUserRepository users;
    @Autowired StudentRepository students;
    @Autowired PasswordEncoder encoder;

    /** Cadastro público recém-enviado: login inativo com papel 'aluno' + aluno pendente. */
    private Student cadastroPendente(String email) {
        AppUser u = new AppUser();
        u.setNome("Pessoa Perfil Teste");
        u.setEmail(email);
        u.setTipoIdentidade("local");
        u.setAtivo(false);
        u.setPasswordHash(encoder.encode(SENHA));
        u.getRoles().add(Roles.ALUNO);
        u = users.save(u);

        Student s = new Student();
        s.setUserId(u.getId());
        s.setFullName("Pessoa Perfil " + UUID.randomUUID());
        s.setCpf(CpfTestFactory.next());
        s.setEmail(email);
        s.setAtestadoData(LocalDate.now());
        s.setStatusCadastro(Student.STATUS_PENDENTE);
        return students.save(s);
    }

    private Student alunoAprovado() {
        Student s = new Student();
        s.setFullName("Aluno da Ficha " + UUID.randomUUID());
        s.setCpf(CpfTestFactory.next());
        return students.save(s);
    }

    private static String email(String prefixo) {
        return prefixo + "." + UUID.randomUUID() + "@goias.gov.br";
    }

    private void aprovar(Student s, String corpo, String token) throws Exception {
        mockMvc.perform(authed(post("/admin/cadastros/" + s.getId() + "/aprovar"), token)
                        .contentType(MediaType.APPLICATION_JSON).content(corpo))
                .andExpect(status().isOk());
    }

    private String login(String email) throws Exception {
        String resposta = mockMvc.perform(post("/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"email\":\"" + email + "\",\"password\":\"" + SENHA + "\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return objectMapper.readTree(resposta).get("accessToken").asText();
    }

    private boolean listagemContem(String token, String query, Student s) throws Exception {
        String json = mockMvc.perform(authed(get("/students?size=100&" + query).param("q", s.getFullName()), token))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        for (JsonNode n : objectMapper.readTree(json).get("content")) {
            if (n.get("id").asText().equals(s.getId().toString())) return true;
        }
        return false;
    }

    @Test
    void aprovarComoInstrutor_trocaPapelAlunoPorProfessorEAtivaOLogin() throws Exception {
        String email = email("instrutor");
        Student s = cadastroPendente(email);

        mockMvc.perform(authed(post("/admin/cadastros/" + s.getId() + "/aprovar"), loginAs("admin"))
                        .contentType(MediaType.APPLICATION_JSON).content("{\"perfil\":\"instrutor\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.studentType").value("Instrutor"));

        AppUser u = users.findById(s.getUserId()).orElseThrow();
        assertThat(u.isAtivo()).isTrue();
        assertThat(u.getRoles()).containsExactly(Roles.PROFESSOR);

        mockMvc.perform(authed(get("/me"), login(email)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.roles.length()").value(1))
                .andExpect(jsonPath("$.roles[0]").value("professor"));
    }

    @Test
    void aprovarSemPerfilOuComoAluno_mantemPapelAluno() throws Exception {
        String token = loginAs("gerente");
        Student semPerfil = cadastroPendente(email("sem.perfil"));
        Student comPerfil = cadastroPendente(email("perfil.aluno"));

        aprovar(semPerfil, "{\"studentType\":\"Civil\"}", token);
        aprovar(comPerfil, "{\"studentType\":\"Militar\",\"perfil\":\"aluno\"}", token);

        assertThat(users.findById(semPerfil.getUserId()).orElseThrow().getRoles()).containsExactly(Roles.ALUNO);
        assertThat(users.findById(comPerfil.getUserId()).orElseThrow().getRoles()).containsExactly(Roles.ALUNO);
        assertThat(students.findById(comPerfil.getId()).orElseThrow().getStudentType()).isEqualTo("Militar");
    }

    @Test
    void perfilInvalido_retorna422_eAlunoSemCategoria_retorna400() throws Exception {
        String token = loginAs("admin");
        Student s = cadastroPendente(email("perfil.invalido"));

        mockMvc.perform(authed(post("/admin/cadastros/" + s.getId() + "/aprovar"), token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"studentType\":\"Civil\",\"perfil\":\"diretor\"}"))
                .andExpect(status().isUnprocessableEntity());
        mockMvc.perform(authed(post("/admin/cadastros/" + s.getId() + "/aprovar"), token)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"perfil\":\"aluno\"}"))
                .andExpect(status().isBadRequest());
        assertThat(students.findById(s.getId()).orElseThrow().getStatusCadastro())
                .isEqualTo(Student.STATUS_PENDENTE);
    }

    @Test
    void instrutor_prescreveFichaParaAluno() throws Exception {
        String email = email("instrutor.ficha");
        aprovar(cadastroPendente(email), "{\"perfil\":\"instrutor\"}", loginAs("admin"));
        String token = login(email);
        Student aluno = alunoAprovado();

        String corpo = """
                {"studentId":"%s","sheetLabel":"B","title":"Ficha B - Costas",
                 "exercises":[{"exerciseName":"Puxada Alta","sets":3,"reps":"10-12","restSeconds":60}]}
                """.formatted(aluno.getId());
        mockMvc.perform(authed(post("/workout-plans"), token)
                        .contentType(MediaType.APPLICATION_JSON).content(corpo))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sheetLabel").value("B"));

        mockMvc.perform(authed(get("/students/" + aluno.getId() + "/workout-plans"), token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].exercises[0].exerciseName").value("Puxada Alta"));
    }

    @Test
    void instrutor_naoFazAgendamento() throws Exception {
        String email = email("instrutor.agenda");
        aprovar(cadastroPendente(email), "{\"perfil\":\"instrutor\"}", loginAs("admin"));

        mockMvc.perform(authed(post("/me/appointments"), login(email))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"date\":\"" + LocalDate.now().plusDays(1) + "\",\"slotStart\":\"08:00\"}"))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value(containsString("instrutor")));
    }

    @Test
    void listagemDeAlunos_filtraPorPerfil() throws Exception {
        String admin = loginAs("admin");
        Student instrutor = cadastroPendente(email("instrutor.lista"));
        aprovar(instrutor, "{\"perfil\":\"instrutor\"}", admin);
        Student aluno = alunoAprovado();

        assertThat(listagemContem(admin, "perfil=aluno", instrutor)).isFalse();
        assertThat(listagemContem(admin, "perfil=instrutor", instrutor)).isTrue();
        assertThat(listagemContem(admin, "", instrutor)).isTrue();
        assertThat(listagemContem(admin, "perfil=aluno", aluno)).isTrue();
        assertThat(listagemContem(admin, "perfil=instrutor", aluno)).isFalse();

        mockMvc.perform(authed(get("/students?perfil=diretor"), admin))
                .andExpect(status().isUnprocessableEntity());
    }

    @Test
    void editarTipoDoCadastro_alinhaOsPapeisDoLogin() throws Exception {
        String admin = loginAs("admin");
        Student s = cadastroPendente(email("troca.perfil"));
        aprovar(s, "{\"studentType\":\"Civil\"}", admin);
        String corpo = "{\"fullName\":\"%s\",\"cpf\":\"%s\",\"studentType\":\"%s\"}";

        mockMvc.perform(authed(put("/students/" + s.getId()), admin).contentType(MediaType.APPLICATION_JSON)
                        .content(corpo.formatted(s.getFullName(), s.getCpf(), "Instrutor")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.studentType").value("Instrutor"));
        assertThat(users.findById(s.getUserId()).orElseThrow().getRoles()).containsExactly(Roles.PROFESSOR);

        mockMvc.perform(authed(put("/students/" + s.getId()), admin).contentType(MediaType.APPLICATION_JSON)
                        .content(corpo.formatted(s.getFullName(), s.getCpf(), "Civil")))
                .andExpect(status().isOk());
        assertThat(users.findById(s.getUserId()).orElseThrow().getRoles()).containsExactly(Roles.ALUNO);

        mockMvc.perform(authed(put("/students/" + s.getId()), admin).contentType(MediaType.APPLICATION_JSON)
                        .content(corpo.formatted(s.getFullName(), s.getCpf(), "Alienígena")))
                .andExpect(status().isUnprocessableEntity());
    }

    /** Editar outros campos de um aluno nunca mexe em papel — quem é aluno E
     *  tem outro papel (ex.: professor, dado por outra via) continua com os dois. */
    @Test
    void editarSemMudarDePerfil_naoAlteraPapeis() throws Exception {
        String admin = loginAs("admin");
        Student s = cadastroPendente(email("dois.papeis"));
        aprovar(s, "{\"studentType\":\"Civil\"}", admin);
        AppUser u = users.findById(s.getUserId()).orElseThrow();
        u.getRoles().add(Roles.PROFESSOR);
        users.save(u);

        mockMvc.perform(authed(put("/students/" + s.getId()), admin).contentType(MediaType.APPLICATION_JSON)
                        .content("{\"fullName\":\"%s\",\"cpf\":\"%s\",\"studentType\":\"Civil\",\"phone\":\"62999990000\"}"
                                .formatted(s.getFullName(), s.getCpf())))
                .andExpect(status().isOk());

        assertThat(users.findById(s.getUserId()).orElseThrow().getRoles())
                .containsExactlyInAnyOrder(Roles.ALUNO, Roles.PROFESSOR);
    }
}
