package br.gov.goias.secami.accelero;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.accelero.AcceleroDtos.CategoriaVinculada;
import br.gov.goias.secami.accelero.AcceleroDtos.EventoAcesso;
import br.gov.goias.secami.accelero.AcceleroDtos.IdentificadorVinculado;
import br.gov.goias.secami.accelero.AcceleroDtos.PaginaEventos;
import br.gov.goias.secami.accelero.AcceleroDtos.PessoaEncontrada;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.context.TestPropertySource;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

/**
 * Regra de negócio da liberação da catraca ao aprovar um cadastro: existe
 * uma única categoria (1213819408) que libera entrada e saída juntas.
 * Militar recebe ela vitalícia na aprovação; Civil não recebe nada na
 * aprovação (só por agendamento — ver AcceleroSchedulingIntegrationTest).
 * Usa {@code @MockBean} em {@link AcceleroClient} — não depende de rede até
 * o Accelero real (só alcançável na rede do governo).
 *
 * <p>{@code secami.accelero.enabled=true} só nesta classe (contexto Spring
 * isolado, cacheado à parte) — no resto da suíte a integração fica desligada
 * por padrão, sem qualquer chamada ao client mockado.
 */
@TestPropertySource(properties = "secami.accelero.enabled=true")
class AcceleroSyncServiceTest extends AbstractIntegrationTest {

    private static final String ACESSO = "1213819408";

    @Autowired private AcceleroSyncService acceleroSync;
    @Autowired private StudentRepository studentRepository;
    @Autowired private AppointmentRepository appointmentRepository;
    @MockBean private AcceleroClient acceleroClient;

    private Student aprovado(String tipo) {
        Student s = new Student();
        s.setFullName("Aluno Accelero " + UUID.randomUUID());
        s.setCpf(CpfTestFactory.next());
        s.setStudentType(tipo);
        s.setStatusCadastro(Student.STATUS_APROVADO);
        s.setActive(true);
        return studentRepository.save(s);
    }

    private void semCategoriasAindaVinculadas() {
        when(acceleroClient.listarCategorias(anyString())).thenReturn(List.of());
    }

    @Test
    void militarLiberaCategoriaUnicaVitalicia() {
        Student s = aprovado("Militar");
        when(acceleroClient.pesquisarPessoas(s.getCpf()))
                .thenReturn(List.of(new PessoaEncontrada("999", "Fulano", s.getCpf())));
        semCategoriasAindaVinculadas();

        acceleroSync.aoAprovar(s);

        verify(acceleroClient).adicionarCategoria("999", ACESSO, "", "");
        Student recarregado = studentRepository.findById(s.getId()).orElseThrow();
        assertThat(recarregado.getAcceleroPessoaId()).isEqualTo("999");
        assertThat(recarregado.getAcceleroLiberadoEm()).isNotNull();
    }

    @Test
    void resincronizaIdentificadoresDaPessoaAposLiberarACategoria() {
        Student s = aprovado("Militar");
        when(acceleroClient.pesquisarPessoas(s.getCpf()))
                .thenReturn(List.of(new PessoaEncontrada("321", "Fulano", s.getCpf())));
        semCategoriasAindaVinculadas();
        when(acceleroClient.listarIdentificadores("321"))
                .thenReturn(List.of(new IdentificadorVinculado("id-1", "Cartão", 1)));

        acceleroSync.aoAprovar(s);

        verify(acceleroClient).desassociarIdentificador("321", "id-1", 1);
    }

    @Test
    void semIdentificadoresNaoTentaDesassociarNadaENaoQuebra() {
        Student s = aprovado("Militar");
        when(acceleroClient.pesquisarPessoas(s.getCpf()))
                .thenReturn(List.of(new PessoaEncontrada("654", "Fulano", s.getCpf())));
        semCategoriasAindaVinculadas();
        when(acceleroClient.listarIdentificadores("654")).thenReturn(List.of());

        acceleroSync.aoAprovar(s);

        verify(acceleroClient, never()).desassociarIdentificador(anyString(), anyString(), any());
    }

    @Test
    void civilNaoRecebeCategoriaNaAprovacao() {
        Student s = aprovado("Civil");
        when(acceleroClient.pesquisarPessoas(s.getCpf()))
                .thenReturn(List.of(new PessoaEncontrada("888", "Ciclana", s.getCpf())));
        semCategoriasAindaVinculadas();

        acceleroSync.aoAprovar(s);

        verify(acceleroClient, never()).adicionarCategoria(anyString(), anyString(), anyString(), anyString());
        Student recarregado = studentRepository.findById(s.getId()).orElseThrow();
        assertThat(recarregado.getAcceleroPessoaId()).isEqualTo("888"); // ainda vincula a pessoa por CPF
    }

    /** Instrutor não agenda horário (trabalha na academia) — recebe o acesso
     *  vitalício na aprovação, igual ao Militar. */
    @Test
    void instrutorLiberaCategoriaVitalicia() {
        Student s = aprovado(Student.TIPO_INSTRUTOR);
        when(acceleroClient.pesquisarPessoas(s.getCpf()))
                .thenReturn(List.of(new PessoaEncontrada("555", "Instrutora", s.getCpf())));
        semCategoriasAindaVinculadas();

        acceleroSync.aoAprovar(s);

        verify(acceleroClient).adicionarCategoria("555", ACESSO, "", "");
        Student recarregado = studentRepository.findById(s.getId()).orElseThrow();
        assertThat(recarregado.getAcceleroLiberadoEm()).isNotNull();
    }

    @Test
    void categoriaJaVinculadaNaoEDuplicada() {
        Student s = aprovado("Militar");
        when(acceleroClient.pesquisarPessoas(s.getCpf()))
                .thenReturn(List.of(new PessoaEncontrada("777", "Beltrano", s.getCpf())));
        when(acceleroClient.listarCategorias("777"))
                .thenReturn(List.of(new CategoriaVinculada("uid-1", ACESSO, "ENTRADA/SAIDA ACADEMIA")));

        acceleroSync.aoAprovar(s);

        verify(acceleroClient, never()).adicionarCategoria(anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void pessoaNaoEncontradaNaoQuebraAAprovacaoEDeixaSemVinculo() {
        Student s = aprovado("Militar");
        when(acceleroClient.pesquisarPessoas(s.getCpf())).thenReturn(List.of());

        acceleroSync.aoAprovar(s);

        verify(acceleroClient, never()).adicionarCategoria(anyString(), anyString(), anyString(), anyString());
        Student recarregado = studentRepository.findById(s.getId()).orElseThrow();
        assertThat(recarregado.getAcceleroPessoaId()).isNull();
    }

    @Test
    void falhaDeComunicacaoComOAcceleroNaoPropaga() {
        Student s = aprovado("Civil");
        when(acceleroClient.pesquisarPessoas(s.getCpf())).thenThrow(new AcceleroException("timeout"));

        acceleroSync.aoAprovar(s); // não deve lançar

        Student recarregado = studentRepository.findById(s.getId()).orElseThrow();
        assertThat(recarregado.getAcceleroPessoaId()).isNull();
    }

    @Test
    void jaVinculadoAnteriormenteNaoPesquisaDeNovoPorCpf() {
        Student s = aprovado("Militar");
        s.setAcceleroPessoaId("555");
        studentRepository.save(s);
        semCategoriasAindaVinculadas();

        acceleroSync.aoAprovar(s);

        verify(acceleroClient, never()).pesquisarPessoas(anyString());
        verify(acceleroClient).adicionarCategoria("555", ACESSO, "", "");
    }

    @Test
    void sincronizarBaseExistenteVinculaTodosOsAprovadosSemAcceleroPessoaId() {
        Student militar = aprovado("Militar");
        Student civil = aprovado("Civil");
        when(acceleroClient.pesquisarPessoas(militar.getCpf()))
                .thenReturn(List.of(new PessoaEncontrada("111", "Militar", militar.getCpf())));
        when(acceleroClient.pesquisarPessoas(civil.getCpf())).thenReturn(List.of());
        semCategoriasAindaVinculadas();

        AcceleroSyncService.ResumoSincronizacao resumo = acceleroSync.sincronizarBaseExistente();

        assertThat(resumo.vinculados()).isGreaterThanOrEqualTo(1);
        assertThat(resumo.naoEncontrados()).isGreaterThanOrEqualTo(1);
        verify(acceleroClient).adicionarCategoria("111", ACESSO, "", "");
    }

    @Test
    void sincronizarBaseExistenteTambemMigraQuemJaEstavaVinculadoComCategoriaAntiga() {
        // Cenário real: militar aprovado ANTES da categoria única existir —
        // já tem accelero_pessoa_id e a categoria antiga de entrada, mas
        // nunca recebeu a 1213819408. O lote precisa alcançar ele também,
        // não só quem nunca foi vinculado.
        Student militar = aprovado("Militar");
        militar.setAcceleroPessoaId("222");
        studentRepository.save(militar);
        when(acceleroClient.listarCategorias("222")).thenReturn(
                List.of(new CategoriaVinculada("uid-antiga", "135315420", "ENTRADA ACADEMIA (categoria antiga)")));

        acceleroSync.sincronizarBaseExistente();

        verify(acceleroClient, never()).pesquisarPessoas(anyString());
        verify(acceleroClient).adicionarCategoria("222", ACESSO, "", "");
    }

    @Test
    void relatorioAcessosFiltraSomentePassagemEfetivamenteRealizada() {
        // area (não controlador) é o que carrega a direção real — confirmado
        // com eventos reais do Accelero: "ACADEMIA EXT" (entrada) / "ACADEMIA
        // INT" (saída), controlador igual ("ACADEMIA") pros dois sentidos.
        Student s = aprovado("Civil");
        s.setAcceleroPessoaId("321");
        studentRepository.save(s);
        when(acceleroClient.listarLogEventos(eq("321"), anyString(), anyString(), eq(1))).thenReturn(
                new PaginaEventos(List.of(
                        new AcceleroDtos.EventoAcesso("2026-08-27 08:00:00", "ACADEMIA", "ACADEMIA EXT",
                                "Passagem efetivamente realizada", 1, "123"),
                        new AcceleroDtos.EventoAcesso("2026-08-27 08:00:05", "ACADEMIA", "ACADEMIA EXT",
                                "Passagem negada", 0, "123"),
                        new AcceleroDtos.EventoAcesso("2026-08-27 09:00:00", "ACADEMIA", "ACADEMIA INT",
                                "Passagem efetivamente realizada", 1, "123")),
                        1));

        var relatorio = acceleroSync.relatorioAcessos(s,
                java.time.LocalDate.of(2026, 8, 1), java.time.LocalDate.of(2026, 8, 31));

        assertThat(relatorio.vinculadoAoAccelero()).isTrue();
        assertThat(relatorio.passagens()).hasSize(2);
        assertThat(relatorio.passagens()).extracting("direcao").containsExactlyInAnyOrder("entrada", "saida");
    }

    @Test
    void classificaDirecaoPeloSufixoDaAreaNaoPeloControlador() {
        // Mesma área/zona (ex.: recepção, prédio principal) segue o mesmo
        // padrão EXT/INT — não é regra específica da academia.
        Student s = aprovado("Civil");
        s.setAcceleroPessoaId("654");
        studentRepository.save(s);
        when(acceleroClient.listarLogEventos(eq("654"), anyString(), anyString(), eq(1))).thenReturn(
                new PaginaEventos(List.of(
                        new AcceleroDtos.EventoAcesso("2026-09-01 08:00:00", "SAIDA TERREO 02", "ATALAIA EXT",
                                "Passagem efetivamente realizada", 1, "123"),
                        new AcceleroDtos.EventoAcesso("2026-09-01 09:00:00", "ENTRADA TERREO 02", "ATALAIA INT",
                                "Passagem efetivamente realizada", 1, "123"),
                        new AcceleroDtos.EventoAcesso("2026-09-01 10:00:00", "CAT SECRETARIADO", "SECRETARIADO",
                                "Passagem efetivamente realizada", 1, "123")),
                        1));

        var relatorio = acceleroSync.relatorioAcessos(s,
                java.time.LocalDate.of(2026, 9, 1), java.time.LocalDate.of(2026, 9, 1));

        assertThat(relatorio.passagens()).extracting("direcao")
                .containsExactlyInAnyOrder("entrada", "saida", "outro");
    }

    @Test
    void excluirAlunoRevogaTodasAsCategoriasVinculadas() {
        // Revoga TUDO que estiver vinculado, seja qual for a categoria — inclusive
        // categorias antigas (pré-unificação) que a pessoa ainda tenha no Accelero.
        Student s = aprovado("Militar");
        s.setAcceleroPessoaId("999");
        studentRepository.save(s);
        when(acceleroClient.listarCategorias("999")).thenReturn(List.of(
                new CategoriaVinculada("uid-acesso", ACESSO, "ENTRADA/SAIDA ACADEMIA"),
                new CategoriaVinculada("uid-antiga", "135315420", "ENTRADA ACADEMIA (categoria antiga)")));

        acceleroSync.aoExcluirAluno(s);

        verify(acceleroClient).excluirCategoria("999", "uid-acesso");
        verify(acceleroClient).excluirCategoria("999", "uid-antiga");
    }

    @Test
    void excluirAlunoSemVinculoNoAcceleroNaoTentaNadaENaoQuebra() {
        Student s = aprovado("Civil"); // sem acceleroPessoaId

        acceleroSync.aoExcluirAluno(s);

        verify(acceleroClient, never()).listarCategorias(anyString());
        verify(acceleroClient, never()).excluirCategoria(anyString(), anyString());
    }

    // ---------- confirmarPresenca (job de confirmação de entrada/saída real) ----------

    private Appointment agendamentoComPessoa(String pessoaId, LocalDate date, String slotStart) {
        Student s = aprovado("Civil");
        s.setAcceleroPessoaId(pessoaId);
        studentRepository.save(s);
        Appointment a = new Appointment();
        a.setStudent(s);
        a.setDate(date);
        a.setSlotStart(slotStart);
        a.setSlotEnd("11:00");
        return appointmentRepository.save(a);
    }

    @Test
    void confirmarPresencaMarcaEntradaESaidaComEventosReais() {
        // Data/hora bem no passado — a janela (20min antes até 5h depois) já
        // começou há muito, não depende do horário em que o teste rodar.
        Appointment a = agendamentoComPessoa("710", LocalDate.now().minusDays(2), "10:00");
        when(acceleroClient.listarLogEventos(eq("710"), anyString(), anyString(), eq(1))).thenReturn(
                new PaginaEventos(List.of(
                        new EventoAcesso("2026-01-01 09:45:00", "ACADEMIA", "ACADEMIA EXT",
                                "Passagem efetivamente realizada", 1, "1"),
                        new EventoAcesso("2026-01-01 11:00:00", "ACADEMIA", "ACADEMIA INT",
                                "Passagem efetivamente realizada", 1, "1")),
                        1));

        boolean mudou = acceleroSync.confirmarPresenca(a);

        assertThat(mudou).isTrue();
        Appointment recarregado = appointmentRepository.findById(a.getId()).orElseThrow();
        assertThat(recarregado.getEntradaConfirmadaEm()).isNotNull();
        assertThat(recarregado.getSaidaConfirmadaEm()).isNotNull();
        assertThat(recarregado.getSaidaConfirmadaEm()).isAfter(recarregado.getEntradaConfirmadaEm());
    }

    @Test
    void confirmarPresencaSoPreencheOQueAindaEstaEmBranco() {
        Appointment a = agendamentoComPessoa("711", LocalDate.now().minusDays(2), "10:00");
        when(acceleroClient.listarLogEventos(eq("711"), anyString(), anyString(), eq(1))).thenReturn(
                new PaginaEventos(List.of(
                        new EventoAcesso("2026-01-01 09:45:00", "ACADEMIA", "ACADEMIA EXT",
                                "Passagem efetivamente realizada", 1, "1")),
                        1));
        acceleroSync.confirmarPresenca(a); // 1ª confirmação real: só entrada
        var recarregado1 = appointmentRepository.findById(a.getId()).orElseThrow();
        var entradaOriginal = recarregado1.getEntradaConfirmadaEm();
        assertThat(entradaOriginal).isNotNull();
        assertThat(recarregado1.getSaidaConfirmadaEm()).isNull();

        // 2ª rodada do job: Accelero agora também tem a saída, e (hipoteticamente)
        // uma entrada diferente — a entrada já confirmada não deve ser sobrescrita.
        when(acceleroClient.listarLogEventos(eq("711"), anyString(), anyString(), eq(1))).thenReturn(
                new PaginaEventos(List.of(
                        new EventoAcesso("2026-01-01 09:50:00", "ACADEMIA", "ACADEMIA EXT",
                                "Passagem efetivamente realizada", 1, "1"),
                        new EventoAcesso("2026-01-01 11:00:00", "ACADEMIA", "ACADEMIA INT",
                                "Passagem efetivamente realizada", 1, "1")),
                        1));
        boolean mudouDeNovo = acceleroSync.confirmarPresenca(recarregado1);

        assertThat(mudouDeNovo).isTrue();
        var recarregado2 = appointmentRepository.findById(a.getId()).orElseThrow();
        assertThat(recarregado2.getEntradaConfirmadaEm()).isEqualTo(entradaOriginal); // não regrediu
        assertThat(recarregado2.getSaidaConfirmadaEm()).isNotNull();
    }

    @Test
    void confirmarPresencaIgnoraEventosDeOutrasAreasDoPredioNaMesmaJanela() {
        // Caso real: a pessoa também tem acesso a outras áreas do prédio
        // (ex.: funcionário) e passa por elas dentro da mesma janela de
        // horário do agendamento da academia — não pode confundir isso com
        // entrada/saída da academia.
        Appointment a = agendamentoComPessoa("713", LocalDate.now().minusDays(2), "10:00");
        when(acceleroClient.listarLogEventos(eq("713"), anyString(), anyString(), eq(1))).thenReturn(
                new PaginaEventos(List.of(
                        new EventoAcesso("2026-01-01 09:49:23", "CAT ATALAIA", "ATALAIA EXT",
                                "Passagem efetivamente realizada", 1, "1"),
                        new EventoAcesso("2026-01-01 09:50:57", "CAT SECRETÁRIADO", "SECRETARIADO EXT",
                                "Passagem efetivamente realizada", 1, "1")),
                        1));

        boolean mudou = acceleroSync.confirmarPresenca(a);

        assertThat(mudou).isFalse();
        Appointment recarregado = appointmentRepository.findById(a.getId()).orElseThrow();
        assertThat(recarregado.getEntradaConfirmadaEm()).isNull();
        assertThat(recarregado.getSaidaConfirmadaEm()).isNull();
    }

    @Test
    void confirmarPresencaAntesDaJanelaComecarNaoConsultaOAccelero() {
        // Agendamento amanhã — a janela (20min antes) ainda nem começou.
        Appointment a = agendamentoComPessoa("712", LocalDate.now().plusDays(1), "10:00");

        boolean mudou = acceleroSync.confirmarPresenca(a);

        assertThat(mudou).isFalse();
        verify(acceleroClient, never()).listarLogEventos(anyString(), anyString(), anyString(), anyInt());
    }

    @Test
    void confirmarPresencaSemPessoaVinculadaRetornaFalse() {
        Student s = aprovado("Civil"); // sem acceleroPessoaId
        Appointment a = new Appointment();
        a.setStudent(s);
        a.setDate(LocalDate.now().minusDays(1));
        a.setSlotStart("10:00");
        a.setSlotEnd("11:00");
        appointmentRepository.save(a);

        boolean mudou = acceleroSync.confirmarPresenca(a);

        assertThat(mudou).isFalse();
        verify(acceleroClient, never()).listarLogEventos(anyString(), anyString(), anyString(), anyInt());
    }

    // ---------- atualizarEmailsComAccelero ----------

    @Test
    void atualizaEmailQuandoAcceleroTemEmailGov() {
        Student s = aprovado("Civil");
        s.setAcceleroPessoaId("901");
        s.setEmail("pessoal@gmail.com");
        studentRepository.save(s);
        when(acceleroClient.detalharPessoa("901")).thenReturn(
                new AcceleroDtos.PessoaDetalhe("901", "Fulano", "Fulano.Silva@goias.gov.br", null));

        var resumo = acceleroSync.atualizarEmailsComAccelero();

        assertThat(resumo.atualizados()).isEqualTo(1);
        assertThat(studentRepository.findById(s.getId()).orElseThrow().getEmail())
                .isEqualTo("fulano.silva@goias.gov.br"); // normalizado em minúsculas
    }

    @Test
    void naoAlteraQuandoEmailDoAcceleroNaoEGov() {
        Student s = aprovado("Civil");
        s.setAcceleroPessoaId("902");
        s.setEmail("pessoal@gmail.com");
        studentRepository.save(s);
        when(acceleroClient.detalharPessoa("902")).thenReturn(
                new AcceleroDtos.PessoaDetalhe("902", "Fulano", "outro@gmail.com", null));

        acceleroSync.atualizarEmailsComAccelero();

        assertThat(studentRepository.findById(s.getId()).orElseThrow().getEmail()).isEqualTo("pessoal@gmail.com");
    }

    @Test
    void naoAlteraQuandoAcceleroNaoTemEmailCadastrado() {
        Student s = aprovado("Civil");
        s.setAcceleroPessoaId("903");
        s.setEmail("pessoal@gmail.com");
        studentRepository.save(s);
        when(acceleroClient.detalharPessoa("903")).thenReturn(
                new AcceleroDtos.PessoaDetalhe("903", "Fulano", null, null));

        var resumo = acceleroSync.atualizarEmailsComAccelero();

        assertThat(resumo.semEmailGov()).isGreaterThanOrEqualTo(1);
        assertThat(studentRepository.findById(s.getId()).orElseThrow().getEmail()).isEqualTo("pessoal@gmail.com");
    }

    @Test
    void ignoraAlunoAindaNaoVinculadoAoAccelero() {
        aprovado("Civil"); // sem acceleroPessoaId — não deve entrar na lista de candidatos

        acceleroSync.atualizarEmailsComAccelero();

        verify(acceleroClient, never()).detalharPessoa(anyString());
    }

    @Test
    void falhaAoAtualizarUmAlunoNaoInterrompeOLote() {
        Student comErro = aprovado("Civil");
        comErro.setAcceleroPessoaId("904");
        studentRepository.save(comErro);
        Student ok = aprovado("Civil");
        ok.setAcceleroPessoaId("905");
        ok.setEmail("pessoal@gmail.com");
        studentRepository.save(ok);
        when(acceleroClient.detalharPessoa("904")).thenThrow(new AcceleroException("timeout"));
        when(acceleroClient.detalharPessoa("905")).thenReturn(
                new AcceleroDtos.PessoaDetalhe("905", "Ciclana", "ciclana@goias.gov.br", null));

        var resumo = acceleroSync.atualizarEmailsComAccelero();

        assertThat(resumo.erros()).isGreaterThanOrEqualTo(1);
        assertThat(resumo.atualizados()).isGreaterThanOrEqualTo(1);
        assertThat(studentRepository.findById(ok.getId()).orElseThrow().getEmail()).isEqualTo("ciclana@goias.gov.br");
    }
}
