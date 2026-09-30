package br.gov.goias.secami.migration;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.migration.MigrationService.AtualizacaoAlunos;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;

import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Atualização incremental dos alunos a partir de uma exportação mais nova do
 * legado: insere os novos e, nos existentes, aplica só o que mudou no legado
 * desde a exportação anterior — sem desfazer o que foi corrigido na plataforma.
 */
class AtualizacaoAlunosTest extends AbstractIntegrationTest {

    private static final String CABECALHO =
            "id,full_name,cpf,email,phone,student_type,weight,height,goal,birth_date,atestado_data,active,is_sample";

    @Autowired MigrationService migration;
    @Autowired StudentRepository students;
    @TempDir Path anterior;
    @TempDir Path nova;

    private final List<String> linhasAnteriores = new ArrayList<>();
    private final List<String> linhasNovas = new ArrayList<>();

    @BeforeEach
    void limpar() {
        linhasAnteriores.clear();
        linhasNovas.clear();
    }

    private static String linha(String id, String nome, String cpf, String email, String peso, String atestado) {
        return String.join(",", id, nome, cpf, email, "62999990000", "Civil", peso, "170", "", "1990-01-01",
                atestado, "true", "false");
    }

    private String legacyId() {
        return "leg-" + UUID.randomUUID();
    }

    /** Aluno que já veio do legado na carga anterior (tem legacy_id). */
    private Student migrado(String legacyId, String cpf, String email, String peso, LocalDate atestado) {
        Student s = new Student();
        s.setLegacyId(legacyId);
        s.setFullName("Aluno Migrado");
        s.setCpf(cpf);
        s.setEmail(email);
        s.setPhone("62999990000");
        s.setWeightKg(peso == null ? null : new BigDecimal(peso));
        s.setHeightCm(new BigDecimal("170"));
        s.setBirthDate(LocalDate.of(1990, 1, 1));
        s.setAtestadoData(atestado);
        return students.save(s);
    }

    private AtualizacaoAlunos rodar(boolean simular) throws Exception {
        Files.write(anterior.resolve("Student_export.csv"), conteudo(linhasAnteriores));
        Files.write(nova.resolve("Student_export.csv"), conteudo(linhasNovas));
        return migration.atualizarAlunos(nova, anterior, simular);
    }

    private static List<String> conteudo(List<String> linhas) {
        List<String> tudo = new ArrayList<>();
        tudo.add(CABECALHO);
        tudo.addAll(linhas);
        return tudo;
    }

    @Test
    void aplicaSoOQueMudouNoLegado_ePreservaOEmailCorrigidoNaPlataforma() throws Exception {
        String id = legacyId();
        String cpf = CpfTestFactory.next();
        // Na plataforma o e-mail já foi trocado pelo institucional depois da carga.
        Student s = migrado(id, cpf, "aluno@goias.gov.br", "80", LocalDate.of(2026, 3, 1));
        linhasAnteriores.add(linha(id, "ALUNO MIGRADO", cpf, "pessoal@gmail.com", "80", "2026-03-01"));
        // No legado: peso e atestado mudaram; o e-mail continua o pessoal de sempre.
        linhasNovas.add(linha(id, "ALUNO MIGRADO", cpf, "pessoal@gmail.com", "84.5", "2026-09-10"));

        AtualizacaoAlunos r = rodar(false);

        assertThat(r.atualizados).isEqualTo(1);
        assertThat(r.itens.get(0).campos()).containsExactlyInAnyOrder("peso", "atestado");
        Student depois = students.findById(s.getId()).orElseThrow();
        assertThat(depois.getWeightKg()).isEqualByComparingTo("84.5");
        assertThat(depois.getAtestadoData()).isEqualTo(LocalDate.of(2026, 9, 10));
        assertThat(depois.getEmail()).isEqualTo("aluno@goias.gov.br");
    }

    @Test
    void semMudancaNoLegado_naoTocaNoAluno() throws Exception {
        String id = legacyId();
        String cpf = CpfTestFactory.next();
        // Peso editado na plataforma (82) difere do legado (80), mas o legado não mudou.
        Student s = migrado(id, cpf, "aluno@goias.gov.br", "82", LocalDate.of(2026, 3, 1));
        linhasAnteriores.add(linha(id, "ALUNO MIGRADO", cpf, "pessoal@gmail.com", "80", "2026-03-01"));
        linhasNovas.add(linha(id, "ALUNO MIGRADO", cpf, "pessoal@gmail.com", "80", "2026-03-01"));

        AtualizacaoAlunos r = rodar(false);

        assertThat(r.semMudanca).isEqualTo(1);
        assertThat(r.atualizados).isZero();
        assertThat(students.findById(s.getId()).orElseThrow().getWeightKg()).isEqualByComparingTo("82");
    }

    @Test
    void emailInstitucionalNuncaETrocadoPorPessoal_masPessoalETrocado() throws Exception {
        String idGov = legacyId(), idPessoal = legacyId();
        String cpfGov = CpfTestFactory.next(), cpfPessoal = CpfTestFactory.next();
        Student gov = migrado(idGov, cpfGov, "aluno@goias.gov.br", "80", null);
        Student pessoal = migrado(idPessoal, cpfPessoal, "antigo@gmail.com", "80", null);
        linhasAnteriores.add(linha(idGov, "A", cpfGov, "antigo@gmail.com", "80", ""));
        linhasAnteriores.add(linha(idPessoal, "B", cpfPessoal, "antigo@gmail.com", "80", ""));
        linhasNovas.add(linha(idGov, "A", cpfGov, "novo@gmail.com", "80", ""));
        linhasNovas.add(linha(idPessoal, "B", cpfPessoal, "Novo@Gmail.com", "80", ""));

        rodar(false);

        assertThat(students.findById(gov.getId()).orElseThrow().getEmail()).isEqualTo("aluno@goias.gov.br");
        assertThat(students.findById(pessoal.getId()).orElseThrow().getEmail()).isEqualTo("novo@gmail.com");
    }

    @Test
    void atestadoSoAvanca() throws Exception {
        String id = legacyId();
        String cpf = CpfTestFactory.next();
        // Renovado na plataforma (set/2026); o legado mudou pra uma data mais antiga.
        Student s = migrado(id, cpf, "a@goias.gov.br", "80", LocalDate.of(2026, 9, 1));
        linhasAnteriores.add(linha(id, "A", cpf, "a@goias.gov.br", "80", "2026-01-01"));
        linhasNovas.add(linha(id, "A", cpf, "a@goias.gov.br", "80", "2026-05-01"));

        AtualizacaoAlunos r = rodar(false);

        assertThat(r.semMudanca).isEqualTo(1);
        assertThat(students.findById(s.getId()).orElseThrow().getAtestadoData()).isEqualTo(LocalDate.of(2026, 9, 1));
    }

    @Test
    void insereAlunoNovo() throws Exception {
        String id = legacyId();
        String cpf = CpfTestFactory.next();
        linhasNovas.add(linha(id, "MARIA DA SILVA", cpf, "maria@gmail.com", "60", "2026-09-20"));

        AtualizacaoAlunos r = rodar(false);

        assertThat(r.inseridos).isEqualTo(1);
        Student novo = students.findByLegacyId(id).orElseThrow();
        assertThat(novo.getFullName()).isEqualTo("Maria Da Silva");
        assertThat(novo.getCpf()).isEqualTo(cpf);
        assertThat(novo.getStatusCadastro()).isEqualTo(Student.STATUS_APROVADO);
        assertThat(novo.getUserId()).isNull();
    }

    /** O legado tem gente cadastrada duas vezes: o recadastro (id novo, mesmo CPF)
     *  só complementa — atestado mais novo e campos vazios; nome/e-mail ficam. */
    @Test
    void recadastroComMesmoCpf_soComplementa() throws Exception {
        String cpf = CpfTestFactory.next();
        Student s = migrado(legacyId(), cpf, "aluno@goias.gov.br", null, null);
        linhasNovas.add(linha(legacyId(), "OUTRO NOME", cpf, "outro@gmail.com", "77", "2026-09-24"));

        AtualizacaoAlunos r = rodar(false);

        assertThat(r.complementados).isEqualTo(1);
        assertThat(r.inseridos).isZero();
        Student depois = students.findById(s.getId()).orElseThrow();
        assertThat(depois.getAtestadoData()).isEqualTo(LocalDate.of(2026, 9, 24));
        assertThat(depois.getWeightKg()).isEqualByComparingTo("77");
        assertThat(depois.getFullName()).isEqualTo("Aluno Migrado");
        assertThat(depois.getEmail()).isEqualTo("aluno@goias.gov.br");
    }

    @Test
    void cadastroPendenteNaPlataforma_naoETocado() throws Exception {
        String cpf = CpfTestFactory.next();
        Student s = migrado(null, cpf, "pendente@goias.gov.br", null, null);
        s.setStatusCadastro(Student.STATUS_PENDENTE);
        students.save(s);
        linhasNovas.add(linha(legacyId(), "PENDENTE", cpf, "x@gmail.com", "70", "2026-09-24"));

        AtualizacaoAlunos r = rodar(false);

        assertThat(r.ignorados).isEqualTo(1);
        Student depois = students.findById(s.getId()).orElseThrow();
        assertThat(depois.getWeightKg()).isNull();
        assertThat(depois.getAtestadoData()).isNull();
    }

    @Test
    void simulacao_relataMasNaoGravaNada() throws Exception {
        String id = legacyId(), idNovo = legacyId();
        String cpf = CpfTestFactory.next();
        Student s = migrado(id, cpf, "a@goias.gov.br", "80", null);
        linhasAnteriores.add(linha(id, "A", cpf, "a@goias.gov.br", "80", ""));
        linhasNovas.add(linha(id, "A", cpf, "a@goias.gov.br", "90", ""));
        linhasNovas.add(linha(idNovo, "NOVO", CpfTestFactory.next(), "n@gmail.com", "60", ""));

        AtualizacaoAlunos r = rodar(true);

        assertThat(r.simulacao).isTrue();
        assertThat(r.atualizados).isEqualTo(1);
        assertThat(r.inseridos).isEqualTo(1);
        students.flush();
        assertThat(students.findById(s.getId()).orElseThrow().getWeightKg()).isEqualByComparingTo("80");
        assertThat(students.findByLegacyId(idNovo)).isEmpty();
    }

    @Test
    void semExportacaoAnterior_insereNovosESoComplementaExistentes() throws Exception {
        String id = legacyId();
        String cpf = CpfTestFactory.next();
        Student s = migrado(id, cpf, "a@goias.gov.br", "80", null);
        linhasNovas.add(linha(id, "A", cpf, "outro@gmail.com", "95", "2026-09-01"));
        Files.write(nova.resolve("Student_export.csv"), conteudo(linhasNovas));

        AtualizacaoAlunos r = migration.atualizarAlunos(nova, null, false);

        assertThat(r.complementados).isEqualTo(1);
        Student depois = students.findById(s.getId()).orElseThrow();
        assertThat(depois.getWeightKg()).isEqualByComparingTo("80"); // já tinha — não troca
        assertThat(depois.getAtestadoData()).isEqualTo(LocalDate.of(2026, 9, 1));
        assertThat(depois.getEmail()).isEqualTo("a@goias.gov.br");
    }
}
