package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.accelero.AcceleroClient;
import br.gov.goias.secami.accelero.AcceleroDtos.EventoAcesso;
import br.gov.goias.secami.accelero.AcceleroDtos.PaginaEventos;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.TestPropertySource;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Job que confere no Accelero se agendamentos de hoje/ontem tiveram entrada
 * e/ou saída real confirmada pela catraca (ver AcceleroSyncService.confirmarPresenca).
 */
@TestPropertySource(properties = "secami.accelero.enabled=true")
class AcceleroPresencaServiceTest extends JobsTestSupport {

    @Autowired private AcceleroPresencaService acceleroPresenca;
    @MockBean private AcceleroClient acceleroClient;

    private Appointment agendamentoComPessoa(String pessoaId, LocalDate date, LocalTime slotStart) {
        Student s = createStudent("presenca-" + pessoaId, "aluno.presenca." + pessoaId + "@dev.secami");
        s.setAcceleroPessoaId(pessoaId);
        studentRepository.save(s);
        return createAppointment(s, date, slotStart, Appointment.CONFIRMADO);
    }

    @Test
    void confirmaEntradaESaidaDeAgendamentoDoDiaComPessoaVinculada() {
        // Data/hora bem no passado — a janela (20min antes até 5h depois) já
        // começou há muito, não depende do horário em que o teste rodar.
        Appointment a = agendamentoComPessoa("810", LocalDate.now().minusDays(1), LocalTime.of(9, 0));
        when(acceleroClient.listarLogEventos(eq("810"), anyString(), anyString(), anyInt())).thenReturn(
                new PaginaEventos(List.of(
                        new EventoAcesso("2026-01-01 08:45:00", "ACADEMIA", "ACADEMIA EXT",
                                "Passagem efetivamente realizada", 1, "1"),
                        new EventoAcesso("2026-01-01 10:00:00", "ACADEMIA", "ACADEMIA INT",
                                "Passagem efetivamente realizada", 1, "1")),
                        1));

        int n = acceleroPresenca.confirmarPresencas();

        assertThat(n).isEqualTo(1);
        Appointment recarregado = appointmentRepository.findById(a.getId()).orElseThrow();
        assertThat(recarregado.getEntradaConfirmadaEm()).isNotNull();
        assertThat(recarregado.getSaidaConfirmadaEm()).isNotNull();
    }

    @Test
    void naoContaAgendamentoSemPessoaVinculada() {
        createAppointment(createStudent("sem-pessoa", "aluno.sem.pessoa@dev.secami"),
                LocalDate.now().minusDays(1), LocalTime.of(9, 0), Appointment.CONFIRMADO);

        int n = acceleroPresenca.confirmarPresencas();

        assertThat(n).isEqualTo(0);
        verify(acceleroClient, never()).listarLogEventos(anyString(), anyString(), anyString(), anyInt());
    }

    @Test
    void naoConsultaDeNovoAgendamentoJaTotalmenteConfirmado() {
        Appointment a = agendamentoComPessoa("820", LocalDate.now().minusDays(1), LocalTime.of(9, 0));
        a.setEntradaConfirmadaEm(OffsetDateTime.now().minusHours(2));
        a.setSaidaConfirmadaEm(OffsetDateTime.now().minusHours(1));
        appointmentRepository.save(a);

        int n = acceleroPresenca.confirmarPresencas();

        assertThat(n).isEqualTo(0);
        verify(acceleroClient, never()).listarLogEventos(eq("820"), anyString(), anyString(), anyInt());
    }
}
