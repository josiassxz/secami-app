package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * SPEC §9.4 — confirmação do agendamento pelo aluno (POST /me/appointments).
 *
 * <p>A confirmação é bloqueada SALVO SE todas as condições abaixo forem verdadeiras:
 * janela de 48h revalidada; atestado válido só para Civil (Militar isento);
 * máx. 2 agendamentos ativos; 1 por dia; sem duplicado exato; capacidade Civil
 * respeitada (Militar sem limite). Cada teste viola exatamente UMA condição, mantendo
 * as demais válidas.
 *
 * <p>Nota sobre "duplicado exato": para um aluno, uma tentativa de duplicar
 * exatamente o mesmo dia+horário SEMPRE também viola "1 por dia" (mesmo dia,
 * por definição) — e "1 por dia" é verificado ANTES do check de duplicado no
 * {@code SchedulingService.doBook}. Ou seja, para o aluno esse gate nunca é o
 * que efetivamente barra a tentativa (o resultado prático é o mesmo: nenhum
 * duplicado é criado, só a mensagem de erro que muda). O check de duplicado
 * "puro" só é alcançável via force-book (staff), que pula a checagem de 1/dia
 * mas mantém a de duplicado — é isso que {@link #condicaoDuplicadoExato_bloqueiaSegundaTentativaIdentica()}
 * exercita.
 */
class BookingConfirmationTest extends SchedulingTestSupport {

    private Student alunoValido(String tipo) throws Exception {
        Student s = newStudent(tipo);
        comFoto(s);
        if ("Civil".equalsIgnoreCase(tipo)) {
            comAtestado(s, hoje().minusMonths(1));
        }
        vinculadoAoUsuario(s, appUserId("aluno"));
        return s;
    }

    @Test
    void fluxoFelizDeConfirmacao_criaAgendamentoStatusAgendadoForcedFalse() throws Exception {
        alunoValido("Civil");
        String token = loginAs("aluno");
        slotAberto("08:00");

        bookAsStudent(token, amanha(), "08:00")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(Appointment.AGENDADO))
                .andExpect(jsonPath("$.forced").value(false));
    }

    // ---- Atestado (só Civil; Militar isento) ----

    @Test
    void civilSemAtestado_bloqueiaConfirmacao() throws Exception {
        Student s = newStudent("Civil");
        comFoto(s); // foto ok, sem atestado
        vinculadoAoUsuario(s, appUserId("aluno"));
        String token = loginAs("aluno");
        slotAberto("08:00");

        bookAsStudent(token, amanha(), "08:00")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Atestado médico ausente ou vencido (validade de 1 ano)."));
    }

    @Test
    void civilComAtestadoVencidoHaMaisDeUmAno_bloqueiaConfirmacao() throws Exception {
        Student s = newStudent("Civil");
        comFoto(s);
        comAtestado(s, hoje().minusYears(1).minusDays(1)); // vencido por 1 dia
        vinculadoAoUsuario(s, appUserId("aluno"));
        String token = loginAs("aluno");
        slotAberto("08:00");

        bookAsStudent(token, amanha(), "08:00")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Atestado médico ausente ou vencido (validade de 1 ano)."));
    }

    @Test
    void civilComAtestadoExatamenteNoLimiteDeUmAno_eValido() throws Exception {
        Student s = newStudent("Civil");
        comFoto(s);
        comAtestado(s, hoje().minusYears(1)); // exatamente 1 ano: ainda válido (limite inclusivo)
        vinculadoAoUsuario(s, appUserId("aluno"));
        String token = loginAs("aluno");
        slotAberto("08:00");

        bookAsStudent(token, amanha(), "08:00").andExpect(status().isOk());
    }

    @Test
    void militarSemAtestado_naoBloqueiaPoisEIsento() throws Exception {
        Student s = newStudent("Militar");
        comFoto(s); // sem atestado — Militar é isento
        vinculadoAoUsuario(s, appUserId("aluno"));
        String token = loginAs("aluno");
        slotAberto("08:00");

        bookAsStudent(token, amanha(), "08:00")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(Appointment.AGENDADO));
    }

    // ---- Janela de 48h revalidada na confirmação ----

    @Test
    void condicaoJanela48h_bloqueiaConfirmacaoDeSlotNoPassado() throws Exception {
        alunoValido("Civil");
        String token = loginAs("aluno");
        slotAberto("08:00"); // slot_config precisa existir para passar do lookup inicial

        bookAsStudent(token, ontem(), "08:00")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Não é possível agendar em horário passado."));
    }

    @Test
    void condicaoJanela48h_bloqueiaConfirmacaoAlemDe48h() throws Exception {
        alunoValido("Civil");
        String token = loginAs("aluno");
        slotAberto("08:00");

        bookAsStudent(token, foraDaJanela(), "08:00")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Só é possível agendar com até 48h de antecedência."));
    }

    // ---- Máx. 2 agendamentos ativos ----

    @Test
    void condicaoMaxDoisAtivos_bloqueiaTerceiroAgendamento() throws Exception {
        Student s = alunoValido("Civil");
        String token = loginAs("aluno");
        // 2 agendamentos ativos já existentes, em datas distintas da que será tentada.
        seedAppointment(s, hoje().plusDays(10), "07:00", Appointment.AGENDADO);
        seedAppointment(s, hoje().plusDays(11), "07:00", Appointment.AGENDADO);
        slotAberto("08:00");

        bookAsStudent(token, amanha(), "08:00")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Você já possui 2 agendamentos ativos."));
    }

    // ---- 1 por dia ----

    @Test
    void condicaoUmPorDia_bloqueiaSegundoAgendamentoNoMesmoDia() throws Exception {
        Student s = alunoValido("Civil");
        String token = loginAs("aluno");
        seedAppointment(s, amanha(), "07:00", Appointment.AGENDADO); // já tem 1 nesse dia
        slotAberto("08:00");

        bookAsStudent(token, amanha(), "08:00")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Você já possui um agendamento neste dia."));
    }

    // ---- Sem duplicado exato (ver nota na Javadoc da classe) ----

    @Test
    void condicaoDuplicadoExato_bloqueiaSegundaTentativaIdentica() throws Exception {
        Student aluno = newStudent("Civil");
        comFoto(aluno);
        comAtestado(aluno, hoje().minusMonths(1));
        String staffToken = loginAs("recepcao");
        slotAberto("08:00");

        forceBook(staffToken, aluno.getId(), amanha(), "08:00", null).andExpect(status().isOk());

        forceBook(staffToken, aluno.getId(), amanha(), "08:00", null)
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.message").value("Já existe agendamento neste horário."));
    }

    // ---- Capacidade Civil (Militar sem limite) ----

    @Test
    void condicaoCapacidadeCivil_bloqueiaCivilQuandoSlotEstaCheio() throws Exception {
        LocalDate date = amanha();
        slot("08:00", 2, false, false); // capacidade 2
        seedCivilFillers(date, "08:00", 2); // já 2 civis ativos = capacidade cheia

        Student s = alunoValido("Civil");
        String token = loginAs("aluno");

        bookAsStudent(token, date, "08:00")
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.message").value("Horário cheio para civis."));
        assertEquals(0, appointmentRepository.findByStudent(s.getId()).size());
    }

    @Test
    void condicaoCapacidadeCivil_naoBloqueiaMilitarMesmoComSlotCheioDeCivis() throws Exception {
        LocalDate date = amanha();
        slot("08:00", 2, false, false); // capacidade 2, já cheia de civis
        seedCivilFillers(date, "08:00", 2);

        Student s = newStudent("Militar");
        comFoto(s); // Militar isento de atestado
        vinculadoAoUsuario(s, appUserId("aluno"));
        String token = loginAs("aluno");

        bookAsStudent(token, date, "08:00")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value(Appointment.AGENDADO));
        assertTrue(appointmentRepository.findByStudent(s.getId()).stream().anyMatch(Appointment::ativo));
    }
}
