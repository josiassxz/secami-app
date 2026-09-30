package br.gov.goias.secami.jobs;

import br.gov.goias.secami.accelero.AcceleroSyncService;
import br.gov.goias.secami.auth.ldap.LdapEmailSyncService;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/** Gatilhos manuais dos jobs (admin), úteis para operação e testes. */
@RestController
@RequestMapping("/admin/jobs")
@PreAuthorize("hasRole('ADMIN')")
public class JobsController {

    private final AbsenceService absenceService;
    private final ReminderService reminderService;
    private final AcceleroSyncService acceleroSync;
    private final AcceleroExpiracaoService acceleroExpiracao;
    private final AcceleroPresencaService acceleroPresenca;
    private final ObjectProvider<LdapEmailSyncService> ldapEmailSync;

    public JobsController(AbsenceService absenceService, ReminderService reminderService,
                           AcceleroSyncService acceleroSync, AcceleroExpiracaoService acceleroExpiracao,
                           AcceleroPresencaService acceleroPresenca,
                           ObjectProvider<LdapEmailSyncService> ldapEmailSync) {
        this.absenceService = absenceService;
        this.reminderService = reminderService;
        this.acceleroSync = acceleroSync;
        this.acceleroExpiracao = acceleroExpiracao;
        this.acceleroPresenca = acceleroPresenca;
        this.ldapEmailSync = ldapEmailSync;
    }

    @PostMapping("/mark-absences")
    public Map<String, Object> markAbsences() {
        int n = absenceService.markAbsences();
        return Map.of("marcados", n);
    }

    @PostMapping("/send-reminders")
    public Map<String, Object> sendReminders() {
        int n = reminderService.sendReminders();
        return Map.of("enviados", n);
    }

    /** Roda em TODOS os alunos aprovados (não só quem nunca foi vinculado) —
     *  vincula por CPF quem falta e garante a categoria/regra atual pra quem
     *  já tinha pessoa vinculada. Idempotente: seguro rodar de novo depois
     *  de uma mudança de categoria no Accelero, pra migrar quem já estava
     *  aprovado antes da mudança. */
    @PostMapping("/sincronizar-accelero")
    public AcceleroSyncService.ResumoSincronizacao sincronizarAccelero() {
        return acceleroSync.sincronizarBaseExistente();
    }

    /** Remove do Accelero o acesso dinâmico do civil cuja janela (20min antes
     *  até 5h depois do início do agendamento) já expirou. */
    @PostMapping("/remover-acessos-expirados")
    public Map<String, Object> removerAcessosExpirados() {
        int n = acceleroExpiracao.removerAcessosExpirados();
        return Map.of("removidos", n);
    }

    /** Confere no Accelero se agendamentos de hoje/ontem tiveram entrada e/ou
     *  saída real confirmada pela catraca. */
    @PostMapping("/confirmar-presencas")
    public Map<String, Object> confirmarPresencas() {
        int n = acceleroPresenca.confirmarPresencas();
        return Map.of("confirmados", n);
    }

    /** Pros alunos já vinculados ao Accelero, atualiza o e-mail aqui quando
     *  o cadastrado lá for do domínio @goias.gov.br. */
    @PostMapping("/atualizar-emails-accelero")
    public AcceleroSyncService.ResumoAtualizacaoEmail atualizarEmailsAccelero() {
        return acceleroSync.atualizarEmailsComAccelero();
    }

    /** Traz o e-mail institucional (@goias.gov.br) do AD, casando pelo CPF, pro
     *  e-mail de contato do aluno. {@code simular=true} (padrão) só conta, sem
     *  gravar — rode assim primeiro. */
    @PostMapping("/atualizar-emails-ldap")
    public LdapEmailSyncService.ResumoEmailLdap atualizarEmailsLdap(
            @RequestParam(defaultValue = "true") boolean simular) {
        LdapEmailSyncService servico = ldapEmailSync.getIfAvailable();
        if (servico == null) {
            throw new BusinessException("O login/consulta via LDAP está desligado (secami.ldap.enabled).");
        }
        return servico.atualizarEmails(simular);
    }
}
