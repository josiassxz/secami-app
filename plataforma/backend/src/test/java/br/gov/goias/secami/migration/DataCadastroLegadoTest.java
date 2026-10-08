package br.gov.goias.secami.migration;

import br.gov.goias.secami.AbstractIntegrationTest;
import br.gov.goias.secami.academy.cadastros.CpfTestFactory;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.beans.factory.annotation.Autowired;

import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/** Data original de cadastro (base do vencimento do atestado) vinda do legado. */
class DataCadastroLegadoTest extends AbstractIntegrationTest {

    @Autowired MigrationService migration;
    @Autowired StudentRepository students;
    @TempDir Path dir;

    private Student aluno(String legacyId, String cpf, LocalDate cadastradoEm) {
        Student s = new Student();
        s.setFullName("Aluno Data " + UUID.randomUUID());
        s.setLegacyId(legacyId);
        s.setCpf(cpf);
        s.setCadastradoEm(cadastradoEm);
        return students.save(s);
    }

    private void csv(String... linhas) throws Exception {
        List<String> tudo = new java.util.ArrayList<>(List.of("id,cpf,created_date,is_sample"));
        tudo.addAll(List.of(linhas));
        Files.write(dir.resolve("Student_export.csv"), tudo);
    }

    @Test
    void preencheFicaComAMaisAntigaEEIdempotente() throws Exception {
        String legacyA = "leg-" + UUID.randomUUID(), legacyB = "leg-" + UUID.randomUUID();
        String cpfC = CpfTestFactory.next();
        Student semData = aluno(legacyA, CpfTestFactory.next(), null);
        Student comDataMaisNova = aluno(legacyB, CpfTestFactory.next(), LocalDate.of(2026, 9, 1));
        Student porCpf = aluno(null, cpfC, LocalDate.of(2026, 9, 21));
        csv(legacyA + ",," + "2026-03-30T10:00:00.000000,false",
            legacyB + ",," + "2026-05-12T08:00:00.000000,false",
            "leg-recadastro," + cpfC + ",2026-06-02T09:00:00.000000,false",
            "leg-inexistente," + CpfTestFactory.next() + ",2026-04-01T09:00:00.000000,false");

        MigrationService.ResultadoDataCadastro sim = migration.preencherDataDeCadastro(dir, true);
        assertThat(sim.atualizados()).isEqualTo(3);
        students.flush();
        assertThat(students.findById(semData.getId()).orElseThrow().getCadastradoEm()).isNull();

        MigrationService.ResultadoDataCadastro r = migration.preencherDataDeCadastro(dir, false);
        assertThat(r.atualizados()).isEqualTo(3);
        assertThat(r.naoEncontrados()).isEqualTo(1);
        assertThat(students.findById(semData.getId()).orElseThrow().getCadastradoEm()).isEqualTo(LocalDate.of(2026, 3, 30));
        assertThat(students.findById(comDataMaisNova.getId()).orElseThrow().getCadastradoEm()).isEqualTo(LocalDate.of(2026, 5, 12));
        assertThat(students.findById(porCpf.getId()).orElseThrow().getCadastradoEm()).isEqualTo(LocalDate.of(2026, 6, 2));

        assertThat(migration.preencherDataDeCadastro(dir, false).atualizados()).isZero();
    }
}
