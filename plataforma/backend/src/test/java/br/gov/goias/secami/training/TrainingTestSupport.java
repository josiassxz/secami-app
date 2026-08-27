package br.gov.goias.secami.training;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.UUID;

/**
 * Base comum aos testes de integração da área de treino (catálogo de
 * exercícios, fichas, coaching). Fornece atalhos para montar dados de teste
 * que não têm endpoint REST próprio (ex.: vincular um {@code Student} a um
 * login existente — {@code Student.userId} não é exposto em
 * {@code StudentDtos.UpsertRequest}) e para criar usuários dev extras além
 * dos 5 semeados por {@code DevDataSeeder} (necessário p.ex. para testar
 * limite de usos de convite, que exige um segundo aluno "real" logando).
 */
public abstract class TrainingTestSupport extends AbstractIntegrationTest {

    @Autowired protected StudentRepository studentRepository;
    @Autowired protected AppUserRepository appUserRepository;
    @Autowired protected PasswordEncoder passwordEncoder;

    /** Busca um dos app_users dev semeados (admin, gerente, recepcao, professor, aluno). */
    protected AppUser devUser(String samAccountName) {
        return appUserRepository.findBySamAccountNameIgnoreCase(samAccountName)
                .orElseThrow(() -> new IllegalStateException(
                        "Usuário dev '" + samAccountName + "' não encontrado — banco de teste sem seed?"));
    }

    /**
     * Cria e persiste um {@link Student} vinculado (via {@code userId}) ao
     * app_user dev informado, para exercitar rotas "/me/*" com um login real
     * (ex.: {@code createStudentFor("aluno")} + {@code loginAs("aluno")}).
     */
    protected Student createStudentFor(String samAccountName) {
        return createStudentFor(samAccountName, "Aluno de Teste " + samAccountName);
    }

    protected Student createStudentFor(String samAccountName, String fullName) {
        Student s = new Student();
        s.setUserId(devUser(samAccountName).getId());
        s.setFullName(fullName);
        s.setStudentType("Civil");
        return studentRepository.save(s);
    }

    /** Cria um {@link Student} avulso, sem login associado — representa "outro aluno" nos testes de isolamento. */
    protected Student createStandaloneStudent(String label) {
        Student s = new Student();
        s.setFullName("Aluno Avulso " + label);
        s.setStudentType("Civil");
        return studentRepository.save(s);
    }

    /**
     * Cria um app_user dev extra (fora dos 5 semeados), com a mesma senha dev
     * ({@code secami123}), pronto para {@link #loginAs(String)}. Útil para
     * cenários que exigem múltiplos atores do mesmo papel (ex.: dois alunos
     * distintos resgatando o mesmo convite até o limite de usos).
     */
    protected AppUser createDevUser(String role) {
        String sam = "test_" + role + "_" + UUID.randomUUID().toString().substring(0, 8);
        AppUser u = new AppUser();
        u.setSamAccountName(sam);
        u.setNome("Usuário Teste " + sam);
        u.setEmail(sam + "@dev.secami");
        u.setTipoIdentidade("local");
        u.setAtivo(true);
        u.setPasswordHash(passwordEncoder.encode(DEV_PASSWORD));
        u.getRoles().add(role);
        return appUserRepository.save(u);
    }
}
