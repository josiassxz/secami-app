package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.accelero.AcceleroClient;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.TestPropertySource;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * Job de limpeza que remove do Accelero o acesso dinâmico do civil (ver
 * AcceleroSyncService) depois que a janela liberada (20min antes até 5h
 * depois do início) expira, mesmo sem cancelamento — o agendamento
 * simplesmente aconteceu e passou.
 */
@TestPropertySource(properties = "secami.accelero.enabled=true")
class AcceleroExpiracaoServiceTest extends JobsTestSupport {

    @Autowired private AcceleroExpiracaoService acceleroExpiracao;
    @MockBean private AcceleroClient acceleroClient;

    private Appointment comAcessoAccelero(String pessoaId, String vinculoId, OffsetDateTime expiraEm) {
        Student s = createStudent("expira", "aluno.expira." + vinculoId + "@dev.secami");
        s.setAcceleroPessoaId(pessoaId);
        studentRepository.save(s);
        Appointment a = createAppointment(s, LocalDate.now(), LocalTime.of(10, 0), Appointment.CONFIRMADO);
        a.setAcceleroAcessoVinculoId(vinculoId);
        a.setAcceleroAcessoExpiraEm(expiraEm);
        return appointmentRepository.save(a);
    }

    @Test
    void removeAcessoDeAgendamentoComJanelaJaExpirada() {
        Appointment a = comAcessoAccelero("111", "vinculo-velho", OffsetDateTime.now().minusHours(1));

        int n = acceleroExpiracao.removerAcessosExpirados();

        assertThat(n).isEqualTo(1);
        verify(acceleroClient).excluirCategoria("111", "vinculo-velho");
        Appointment recarregado = appointmentRepository.findById(a.getId()).orElseThrow();
        assertThat(recarregado.getAcceleroAcessoVinculoId()).isNull();
        assertThat(recarregado.getAcceleroAcessoExpiraEm()).isNull();
    }

    @Test
    void naoRemoveAcessoAindaDentroDaJanela() {
        Appointment a = comAcessoAccelero("222", "vinculo-ativo", OffsetDateTime.now().plusHours(1));

        int n = acceleroExpiracao.removerAcessosExpirados();

        assertThat(n).isEqualTo(0);
        verify(acceleroClient, never()).excluirCategoria("222", "vinculo-ativo");
        Appointment recarregado = appointmentRepository.findById(a.getId()).orElseThrow();
        assertThat(recarregado.getAcceleroAcessoVinculoId()).isEqualTo("vinculo-ativo");
    }

    @Test
    void ignoraAgendamentoSemAcessoLiberado() {
        createAppointment(createStudent("sem-acesso", "aluno.sem.acesso@dev.secami"),
                LocalDate.now().minusDays(1), LocalTime.of(9, 0), Appointment.FALTOU);

        int n = acceleroExpiracao.removerAcessosExpirados();

        assertThat(n).isEqualTo(0);
        verify(acceleroClient, never()).excluirCategoria(org.mockito.ArgumentMatchers.anyString(), org.mockito.ArgumentMatchers.anyString());
    }
}
