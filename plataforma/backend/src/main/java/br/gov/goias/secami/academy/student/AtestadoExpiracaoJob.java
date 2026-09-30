package br.gov.goias.secami.academy.student;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.List;

/**
 * Job diário que inativa alunos cujo atestado venceu (mais de 1 ano)
 * e que ainda estavam com situação ATIVO.
 */
@Component
public class AtestadoExpiracaoJob {

    private static final Logger log = LoggerFactory.getLogger(AtestadoExpiracaoJob.class);

    private final StudentRepository students;

    public AtestadoExpiracaoJob(StudentRepository students) {
        this.students = students;
    }

    @Scheduled(cron = "0 0 2 * * *") // Diário às 02:00
    @Transactional
    public void inativarAlunosComAtestadoVencido() {
        LocalDate limite = LocalDate.now().minusYears(1);
        List<Student> vencidos = students.findComAtestadoVencido(limite);
        int count = 0;
        for (Student s : vencidos) {
            if (Student.SITUACAO_ATIVO.equals(s.getSituacao())) {
                s.setSituacao(Student.SITUACAO_INATIVO);
                students.save(s);
                count++;
            }
        }
        if (count > 0) {
            log.info("AtestadoExpiracaoJob: {} aluno(s) inativado(s) por atestado vencido.", count);
        }
    }
}