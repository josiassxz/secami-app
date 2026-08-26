package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.student.Student;
import org.junit.jupiter.api.Test;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * SPEC §9.4/§9.5 — RBAC do agendamento/check-in: aluno não pode force-book nem
 * fazer check-in de outro aluno; os papéis de staff corretos podem, conforme
 * {@code @PreAuthorize} de {@code AppointmentController#forceBook} (ADMIN, GERENTE,
 * RECEPCAO) e {@code CheckInController} (ADMIN, RECEPCAO, PROFESSOR — a nível de classe).
 */
class SchedulingRbacTest extends SchedulingTestSupport {

    private Student alunoForceBookable() {
        Student s = newStudent("Militar"); // militar: isento de atestado, só precisa de foto
        comFoto(s);
        return s;
    }

    // ---- Force-book: POST /appointments ----

    @Test
    void alunoNaoPodeForceBook() throws Exception {
        Student alvo = alunoForceBookable();
        slotAberto("08:00");
        String token = loginAs("aluno");

        forceBook(token, alvo.getId(), amanha(), "08:00", null).andExpect(status().isForbidden());
    }

    @Test
    void professorNaoPodeForceBook() throws Exception {
        Student alvo = alunoForceBookable();
        slotAberto("08:00");
        String token = loginAs("professor");

        forceBook(token, alvo.getId(), amanha(), "08:00", null).andExpect(status().isForbidden());
    }

    @Test
    void recepcaoPodeForceBook() throws Exception {
        Student alvo = alunoForceBookable();
        slotAberto("08:00");
        String token = loginAs("recepcao");

        forceBook(token, alvo.getId(), amanha(), "08:00", null).andExpect(status().isOk());
    }

    @Test
    void adminPodeForceBook() throws Exception {
        Student alvo = alunoForceBookable();
        slotAberto("08:00");
        String token = loginAs("admin");

        forceBook(token, alvo.getId(), amanha(), "08:00", null).andExpect(status().isOk());
    }

    // ---- Check-in: POST /checkins ----

    @Test
    void alunoNaoPodeFazerCheckInDeOutroAluno() throws Exception {
        Student alvo = civil();
        String token = loginAs("aluno");

        doCheckIn(token, alvo.getId(), hoje(), null).andExpect(status().isForbidden());
    }

    @Test
    void gerenteNaoPodeFazerCheckIn() throws Exception {
        Student alvo = civil();
        String token = loginAs("gerente");

        doCheckIn(token, alvo.getId(), hoje(), null).andExpect(status().isForbidden());
    }

    @Test
    void recepcaoPodeFazerCheckIn() throws Exception {
        Student alvo = civil();
        String token = loginAs("recepcao");

        doCheckIn(token, alvo.getId(), hoje(), null).andExpect(status().isOk());
    }

    @Test
    void professorPodeFazerCheckIn() throws Exception {
        Student alvo = civil();
        String token = loginAs("professor");

        doCheckIn(token, alvo.getId(), hoje(), null).andExpect(status().isOk());
    }

    @Test
    void adminPodeFazerCheckIn() throws Exception {
        Student alvo = civil();
        String token = loginAs("admin");

        doCheckIn(token, alvo.getId(), hoje(), null).andExpect(status().isOk());
    }
}
