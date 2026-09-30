package br.gov.goias.secami.academy.agendamento;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.accelero.AcceleroClient;
import br.gov.goias.secami.accelero.AcceleroDtos.CategoriaVinculada;
import br.gov.goias.secami.accelero.AcceleroDtos.IdentificadorVinculado;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.TestPropertySource;

import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * Acesso dinâmico no Accelero por agendamento (Civil): liberado 20min antes
 * do horário marcado até 5h depois do início, ao agendar; revogado ao
 * cancelar. Militar não dispara nada aqui (já tem acesso vitalício desde a
 * aprovação).
 *
 * <p>Exercita a pilha real (controller → SchedulingService → AcceleroSyncService)
 * com {@code @MockBean} em {@link AcceleroClient} — a regra de "quando" chamar
 * o Accelero é o que está sob teste aqui; a regra de "o que" chamar (idempotência,
 * vinculação por CPF) já é coberta por {@code AcceleroSyncServiceTest}.
 */
@TestPropertySource(properties = "secami.accelero.enabled=true")
class AcceleroSchedulingIntegrationTest extends SchedulingTestSupport {

    private static final String ACESSO = "1213819408";

    @MockBean private AcceleroClient acceleroClient;

    private Student civilPronto(String acceleroPessoaId) {
        Student s = comAtestado(comFoto(civil()), hoje());
        s.setAcceleroPessoaId(acceleroPessoaId);
        return studentRepository.save(s);
    }

    @Test
    void agendarComoCivilLiberaAcessoDe20MinAntesAte5hDepoisDoInicio() throws Exception {
        Student s = civilPronto("456");
        UUID userId = newAlunoUser("civil.entrada");
        s.setUserId(userId);
        studentRepository.save(s);
        String token = loginAs("civil.entrada");

        slotAberto("10:00");
        when(acceleroClient.listarCategorias("456")).thenReturn(List.of());
        when(acceleroClient.listarIdentificadores("456"))
                .thenReturn(List.of(new IdentificadorVinculado("id-1", "Rosto", 1)));

        bookAsStudent(token, amanha(), "10:00").andExpect(status().isOk());

        ArgumentCaptor<String> inicioCap = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> fimCap = ArgumentCaptor.forClass(String.class);
        verify(acceleroClient).adicionarCategoria(eq("456"), eq(ACESSO), inicioCap.capture(), fimCap.capture());

        assertThat(inicioCap.getValue()).contains("09:40"); // 20min antes de 10:00
        assertThat(fimCap.getValue()).contains("15:00"); // 5h depois do início marcado (10:00), não do slotEnd
        verify(acceleroClient).desassociarIdentificador("456", "id-1", 1); // ressincroniza depois da categoria
    }

    @Test
    void cancelarAgendamentoRevogaOAcessoLiberado() throws Exception {
        Student s = civilPronto("789");
        UUID userId = newAlunoUser("civil.cancela");
        s.setUserId(userId);
        studentRepository.save(s);
        String token = loginAs("civil.cancela");

        slotAberto("11:00");
        when(acceleroClient.listarCategorias("789"))
                .thenReturn(List.of()) // snapshot ANTES de liberar
                .thenReturn(List.of(new CategoriaVinculada("vinculo-novo", ACESSO, "ENTRADA/SAIDA ACADEMIA"))); // DEPOIS

        var bookJson = readJson(bookAsStudent(token, amanha(), "11:00").andExpect(status().isOk()));
        UUID appointmentId = UUID.fromString(bookJson.get("id").asText());

        verify(acceleroClient).adicionarCategoria(eq("789"), eq(ACESSO), anyString(), anyString());
        Appointment recarregado = appointmentRepository.findById(appointmentId).orElseThrow();
        assertThat(recarregado.getAcceleroAcessoVinculoId()).isEqualTo("vinculo-novo");
        assertThat(recarregado.getAcceleroAcessoExpiraEm()).isNotNull();

        cancelAppointment(token, appointmentId).andExpect(status().isOk());

        verify(acceleroClient).excluirCategoria("789", "vinculo-novo");
        Appointment cancelado = appointmentRepository.findById(appointmentId).orElseThrow();
        assertThat(cancelado.getAcceleroAcessoVinculoId()).isNull();
        assertThat(cancelado.getAcceleroAcessoExpiraEm()).isNull();
        assertThat(cancelado.getStatus()).isEqualTo(Appointment.CANCELADO);
    }

    @Test
    void agendarComoMilitarNaoDisparaAcessoDinamico() throws Exception {
        Student s = comFoto(militar());
        UUID userId = newAlunoUser("militar.entrada");
        s.setUserId(userId);
        studentRepository.save(s);
        String token = loginAs("militar.entrada");

        slotAberto("14:00");

        bookAsStudent(token, amanha(), "14:00").andExpect(status().isOk());

        verifyNoInteractions(acceleroClient);
    }
}
