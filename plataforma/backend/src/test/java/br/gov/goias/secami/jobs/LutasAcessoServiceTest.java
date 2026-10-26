package br.gov.goias.secami.jobs;

import br.gov.goias.secami.academy.lutas.AcessoLutasRepository;
import br.gov.goias.secami.academy.slot.BlockedDate;
import br.gov.goias.secami.academy.slot.BlockedDateRepository;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.accelero.AcceleroClient;
import br.gov.goias.secami.accelero.AcceleroDtos.CategoriaVinculada;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.TestPropertySource;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.TemporalAdjusters;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Perfil Lutas: catraca liberada no horário da aula nos dias da turma
 * (padrão: masculino ter/qui/sex, feminino seg/qua/sex, 12:00–13:00, folga de
 * 2h pra sair, abre 20 min antes).
 */
@TestPropertySource(properties = "secami.accelero.enabled=true")
class LutasAcessoServiceTest extends JobsTestSupport {

    private static final ZoneId SP = ZoneId.of("America/Sao_Paulo");
    private static final String ACESSO = "1213819408";

    @Autowired private LutasAcessoService lutas;
    @Autowired private AcessoLutasRepository acessos;
    @Autowired private BlockedDateRepository blockedDates;
    @MockBean private AcceleroClient acceleroClient;

    private Student masc, fem;

    @BeforeEach
    void turmas() {
        // Só os alunos deste teste: os de Lutas que existirem na base local não interferem nas contas.
        studentRepository.findByDeletedAtIsNullAndStatusCadastroAndStudentType(Student.STATUS_APROVADO, Student.TIPO_LUTAS)
                .forEach(s -> { s.setStudentType(Student.TIPO_CIVIL); s.setTurmaLutas(null); studentRepository.save(s); });
        masc = aluno("masc", "901", Student.TURMA_MASCULINO);
        fem = aluno("fem", "902", Student.TURMA_FEMININO);
        when(acceleroClient.listarCategorias(anyString())).thenReturn(List.of(),
                List.of(new CategoriaVinculada("vinc-novo", ACESSO, "ENTRADA/SAIDA ACADEMIA")));
    }

    private Student aluno(String label, String pessoaId, String turma) {
        Student s = createStudent("lutas-" + label, "lutas." + label + "@dev.secami");
        s.setStudentType(Student.TIPO_LUTAS);
        s.setTurmaLutas(turma);
        s.setAcceleroPessoaId(pessoaId);
        return studentRepository.save(s);
    }

    private static ZonedDateTime proxima(DayOfWeek dia, int hora) {
        LocalDate d = LocalDate.now(SP).plusDays(1).with(TemporalAdjusters.nextOrSame(dia));
        return ZonedDateTime.of(d, LocalTime.of(hora, 0), SP);
    }

    @Test
    void terca_liberaSoATurmaMasculinaDas1140As1500() {
        int n = lutas.liberarDoDia(proxima(DayOfWeek.TUESDAY, 8));

        assertThat(n).isEqualTo(1);
        ArgumentCaptor<String> inicio = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<String> fim = ArgumentCaptor.forClass(String.class);
        verify(acceleroClient).adicionarCategoria(eq("901"), eq(ACESSO), inicio.capture(), fim.capture());
        assertThat(inicio.getValue()).endsWith("11:40:00");
        assertThat(fim.getValue()).endsWith("15:00:00");
        verify(acceleroClient, never()).adicionarCategoria(eq("902"), anyString(), anyString(), anyString());
    }

    @Test
    void sextaEMista_liberaAsDuasTurmas() {
        lutas.liberarDoDia(proxima(DayOfWeek.FRIDAY, 8));

        verify(acceleroClient).adicionarCategoria(eq("901"), eq(ACESSO), anyString(), anyString());
        verify(acceleroClient).adicionarCategoria(eq("902"), eq(ACESSO), anyString(), anyString());
    }

    @Test
    void naoRepeteALiberacaoNoMesmoDia() {
        ZonedDateTime segunda = proxima(DayOfWeek.MONDAY, 8);
        lutas.liberarDoDia(segunda);
        lutas.liberarDoDia(segunda.plusHours(2));

        verify(acceleroClient, times(1)).adicionarCategoria(eq("902"), eq(ACESSO), anyString(), anyString());
    }

    @Test
    void depoisDaJanelaOuEmDiaSemAulaNaoLibera() {
        assertThat(lutas.liberarDoDia(proxima(DayOfWeek.TUESDAY, 15))).isZero(); // janela já acabou
        assertThat(lutas.liberarDoDia(proxima(DayOfWeek.SUNDAY, 8))).isZero();
        verify(acceleroClient, never()).adicionarCategoria(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void dataBloqueadaODiaTodoNaoLibera() {
        ZonedDateTime quarta = proxima(DayOfWeek.WEDNESDAY, 8);
        BlockedDate b = new BlockedDate();
        b.setDate(quarta.toLocalDate());
        b.setReason("Feriado");
        blockedDates.save(b);

        assertThat(lutas.liberarDoDia(quarta)).isZero();
    }

    @Test
    void retiraALiberacaoDepoisQueAJanelaAcaba() {
        lutas.liberarDoDia(proxima(DayOfWeek.TUESDAY, 8));
        var a = acessos.findAll().stream().filter(x -> x.getStudent().getId().equals(masc.getId())).findFirst().orElseThrow();
        a.setExpiraEm(OffsetDateTime.now().minusMinutes(1));
        acessos.save(a);

        assertThat(lutas.retirarVencidas()).isEqualTo(1);
        verify(acceleroClient).excluirCategoria("901", "vinc-novo");
        assertThat(acessos.findById(a.getId()).orElseThrow().getAcceleroVinculoId()).isNull();
    }
}
