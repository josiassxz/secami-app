package br.gov.goias.secami.academy.student;

import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Mantém os papéis do login coerentes com o perfil do cadastro: tipo
 * {@code Instrutor} → papel {@code professor} (perfil "Instrutor" no app e no
 * admin), sem o papel {@code aluno}; Civil/Militar → papel {@code aluno}, sem
 * {@code professor}. Os demais papéis (admin, gerente, recepção) não são
 * tocados.
 *
 * <p>Chamado só quando o perfil é decidido ou muda (aprovação do cadastro,
 * edição do tipo pelo admin) — nunca a cada gravação do aluno, pra não
 * desfazer um papel atribuído de outra forma.
 */
@Service
public class StudentPerfilService {

    private final AppUserRepository users;

    public StudentPerfilService(AppUserRepository users) {
        this.users = users;
    }

    @Transactional
    public void sincronizarPapeis(Student student) {
        if (student.getUserId() == null) return; // sem login ainda — nada a alinhar
        users.findById(student.getUserId()).ifPresent(user -> {
            boolean mudou;
            if (student.isInstrutor()) {
                mudou = user.getRoles().remove(Roles.ALUNO);
                mudou |= user.getRoles().add(Roles.PROFESSOR);
            } else {
                mudou = user.getRoles().remove(Roles.PROFESSOR);
                mudou |= user.getRoles().add(Roles.ALUNO);
            }
            if (mudou) users.save(user);
        });
    }
}
