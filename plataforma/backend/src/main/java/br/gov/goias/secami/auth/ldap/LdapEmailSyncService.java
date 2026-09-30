package br.gov.goias.secami.auth.ldap;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.common.EmailInstitucional;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Traz o e-mail institucional (@goias.gov.br) do AD pro cadastro do aluno: a
 * base migrada tem majoritariamente e-mail pessoal, e os lembretes de
 * agendamento saem pro {@code student.email}. O casamento é pelo CPF (guardado
 * no AD, campo de texto livre). Só o e-mail de CONTATO do aluno muda — o
 * e-mail de login ({@code app_user.email}) fica como está, pra ninguém ser
 * trancado pra fora por trocar o e-mail que usa pra entrar.
 */
@Service
@ConditionalOnProperty(name = "secami.ldap.enabled", havingValue = "true")
public class LdapEmailSyncService {

    private static final Logger log = LoggerFactory.getLogger(LdapEmailSyncService.class);
    private static final int LIMITE_AMOSTRA = 50;

    private final LdapDirectory directory;
    private final StudentRepository students;

    public LdapEmailSyncService(LdapDirectory directory, StudentRepository students) {
        this.directory = directory;
        this.students = students;
    }

    /**
     * @param simular true = só conta o que faria, sem gravar nada.
     */
    @Transactional
    public ResumoEmailLdap atualizarEmails(boolean simular) {
        List<Student> candidatos = students.findByCpfIsNotNullAndDeletedAtIsNull().stream()
                .filter(s -> Cpf.isValid(s.getCpf()))
                .toList();

        Map<String, List<LdapUser>> noAd;
        try {
            noAd = directory.buscarPorCpfs(candidatos.stream().map(Student::getCpf).toList());
        } catch (LdapUnavailableException e) {
            log.error("Atualização de e-mails via AD abortada: {}", e.getMessage(), e);
            throw new BusinessException("Não foi possível consultar o AD agora. Tente de novo em instantes.");
        }

        int encontrados = 0, atualizados = 0, jaCorretos = 0, semEmailGov = 0, naoEncontrados = 0,
                ambiguos = 0, substituidosGov = 0;
        List<Mudanca> substituicoes = new ArrayList<>();
        for (Student s : candidatos) {
            List<LdapUser> contas = noAd.getOrDefault(s.getCpf(), List.of());
            if (contas.isEmpty()) {
                naoEncontrados++;
                continue;
            }
            if (contas.size() > 1) {
                ambiguos++;
                log.warn("AD: {} contas ativas com o CPF do aluno {} — ignorado por ambiguidade.",
                        contas.size(), s.getId());
                continue;
            }
            encontrados++;
            String novo = EmailInstitucional.normalizar(contas.get(0).email()).orElse(null);
            if (novo == null) {
                semEmailGov++;
            } else if (novo.equalsIgnoreCase(s.getEmail())) {
                jaCorretos++;
            } else {
                boolean jaEraGov = EmailInstitucional.normalizar(s.getEmail()).isPresent();
                if (jaEraGov) {
                    substituidosGov++;
                    if (substituicoes.size() < LIMITE_AMOSTRA) {
                        substituicoes.add(new Mudanca(s.getFullName(), s.getEmail(), novo));
                    }
                }
                if (!simular) s.setEmail(novo);
                atualizados++;
            }
        }
        if (!simular) students.saveAll(candidatos);

        ResumoEmailLdap resumo = new ResumoEmailLdap(simular, candidatos.size(), encontrados, atualizados,
                jaCorretos, semEmailGov, naoEncontrados, ambiguos, substituidosGov, substituicoes);
        log.info("E-mails via AD{}: candidatos={}, encontrados={}, atualizados={}, jaCorretos={}, semEmailGov={}, "
                + "naoEncontrados={}, ambiguos={}, substituidosGov={}", simular ? " (SIMULAÇÃO)" : "",
                candidatos.size(), encontrados, atualizados, jaCorretos, semEmailGov, naoEncontrados,
                ambiguos, substituidosGov);
        return resumo;
    }

    /**
     * @param candidatos     alunos com CPF válido
     * @param encontrados    com exatamente 1 conta ativa no AD com esse CPF
     * @param atualizados    e-mail trocado (ou que seria, na simulação) por um @goias.gov.br do AD
     * @param jaCorretos     já estavam com o mesmo e-mail do AD
     * @param semEmailGov    achados no AD, mas o e-mail de lá está vazio ou não é @goias.gov.br
     * @param naoEncontrados CPF sem conta ativa no AD (ou AD sem o CPF no campo de texto)
     * @param ambiguos       mais de uma conta ativa com o mesmo CPF (ignorados)
     * @param substituidosGov subconjunto de {@code atualizados} que já tinham OUTRO e-mail @goias.gov.br
     * @param substituicoesGov amostra (até {@value #LIMITE_AMOSTRA}) dessas trocas gov→gov, pra conferência
     */
    public record ResumoEmailLdap(boolean simulacao, int candidatos, int encontrados, int atualizados,
                                   int jaCorretos, int semEmailGov, int naoEncontrados, int ambiguos,
                                   int substituidosGov, List<Mudanca> substituicoesGov) {}

    public record Mudanca(String aluno, String de, String para) {}
}
