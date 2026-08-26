package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import org.junit.jupiter.api.Test;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * SPEC §9.4 — force-book pela recepção/gestão (POST /appointments).
 *
 * <p>Exige foto e (se Civil) atestado válido — os mesmos gates comuns ao aluno —
 * mas PULA janela de 48h, máx. 2 ativos, 1 por dia e capacidade Civil. Cria
 * {@code forced=true}.
 */
class ForceBookTest extends SchedulingTestSupport {

    @Test
    void forceBookPulaJanela48hMaxAtivosUmPorDiaECapacidade_aindaAssimCriaAgendamentoForcado() throws Exception {
        Student aluno = newStudent("Civil");
        comFoto(aluno);
        comAtestado(aluno, hoje().minusMonths(1));

        // Viola "máx. 2 ativos": já tem 2 agendamentos ativos em outras datas.
        seedAppointment(aluno, hoje().plusDays(20), "07:00", Appointment.AGENDADO);
        seedAppointment(aluno, hoje().plusDays(21), "07:00", Appointment.AGENDADO);
        // Viola "1 por dia": já tem outro agendamento no MESMO dia do alvo.
        seedAppointment(aluno, foraDaJanela(), "07:00", Appointment.AGENDADO);
        // Viola "capacidade Civil": slot no dia-alvo já com 1/1 civis (capacidade cheia).
        slot("08:00", 1, false, false);
        seedCivilFillers(foraDaJanela(), "08:00", 1);
        // Viola "janela de 48h": data-alvo está a mais de 48h de distância.

        String staffToken = loginAs("recepcao");
        forceBook(staffToken, aluno.getId(), foraDaJanela(), "08:00", "vaga extra concedida pela recepção")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(Appointment.AGENDADO))
                .andExpect(jsonPath("$.forced").value(true));
    }

    @Test
    void forceBookAindaAssimExigeFoto() throws Exception {
        Student aluno = newStudent("Civil");
        comAtestado(aluno, hoje().minusMonths(1)); // atestado ok, sem foto
        slotAberto("08:00");

        String staffToken = loginAs("recepcao");
        forceBook(staffToken, aluno.getId(), amanha(), "08:00", null)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Foto obrigatória para reconhecimento facial da catraca."));
    }

    @Test
    void forceBookAindaAssimExigeAtestadoParaCivil() throws Exception {
        Student aluno = newStudent("Civil");
        comFoto(aluno); // foto ok, sem atestado
        slotAberto("08:00");

        String staffToken = loginAs("recepcao");
        forceBook(staffToken, aluno.getId(), amanha(), "08:00", null)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Atestado médico ausente ou vencido (validade de 1 ano)."));
    }

    @Test
    void forceBookComAtestadoVencidoAindaBloqueiaCivil() throws Exception {
        Student aluno = newStudent("Civil");
        comFoto(aluno);
        comAtestado(aluno, hoje().minusYears(1).minusDays(1));
        slotAberto("08:00");

        String staffToken = loginAs("recepcao");
        forceBook(staffToken, aluno.getId(), amanha(), "08:00", null)
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Atestado médico ausente ou vencido (validade de 1 ano)."));
    }

    @Test
    void forceBookMilitarSemAtestadoFunciona() throws Exception {
        Student aluno = newStudent("Militar");
        comFoto(aluno); // Militar isento de atestado, mesmo em force-book
        slotAberto("08:00");

        String staffToken = loginAs("recepcao");
        forceBook(staffToken, aluno.getId(), amanha(), "08:00", null)
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.forced").value(true));
    }
}
