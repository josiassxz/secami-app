package br.gov.goias.secami.academy.atestado;

import br.gov.goias.secami.academy.appointment.Appointment;
import br.gov.goias.secami.academy.appointment.AppointmentRepository;
import br.gov.goias.secami.academy.appointment.SchedulingService;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.AlunoAtestado;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.Envio;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.EnvioRequest;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.Pendente;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.ResultadoBloqueio;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.Resumo;
import br.gov.goias.secami.academy.atestado.AtestadoDtos.Status;
import br.gov.goias.secami.academy.media.Media;
import br.gov.goias.secami.academy.media.MediaStorageService;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.ConflictException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.config.SecamiProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.Comparator;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * Vencimento do atestado médico (só aluno civil — militar e instrutor ficam
 * de fora): vale 1 ano a partir da data do atestado ou, sem ela, da data
 * original de cadastro ({@link Student#vencimentoAtestado()}). Faltando 30
 * dias, o app avisa a cada entrada; vencido, o acesso é bloqueado (não agenda
 * — e, pro civil, a catraca só abre por agendamento) até a academia validar um
 * novo atestado enviado pelo próprio aluno.
 */
@Service
public class AtestadoService {

    private static final Logger log = LoggerFactory.getLogger(AtestadoService.class);
    /** Janela do aviso "vai vencer" (dias antes do vencimento). */
    public static final int DIAS_AVISO = 30;

    private final StudentRepository students;
    private final AtestadoEnvioRepository envios;
    private final AppointmentRepository appointments;
    private final SchedulingService scheduling;
    private final MediaStorageService storage;
    private final ZoneId zone;

    public AtestadoService(StudentRepository students, AtestadoEnvioRepository envios,
                           AppointmentRepository appointments, SchedulingService scheduling,
                           MediaStorageService storage, SecamiProperties props) {
        this.students = students;
        this.envios = envios;
        this.appointments = appointments;
        this.scheduling = scheduling;
        this.storage = storage;
        this.zone = ZoneId.of(props.getTimezone());
    }

    public LocalDate hoje() {
        return LocalDate.now(zone);
    }

    // ---------- aluno (app) ----------

    @Transactional(readOnly = true)
    public Status statusDoUsuario(UUID userId) {
        Student s = students.findByUserId(userId).orElse(null);
        if (s == null || !Student.STATUS_APROVADO.equals(s.getStatusCadastro()) || !s.sujeitoAoAtestado()) {
            return Status.naoAplicavel();
        }
        return status(s, hoje());
    }

    Status status(Student s, LocalDate hoje) {
        LocalDate vencimento = s.vencimentoAtestado();
        Envio envio = envioRelevante(s.getId());
        if (vencimento == null) {
            // Sem data nenhuma (não deveria acontecer após a carga): trata como vencido.
            return new Status(true, AtestadoDtos.VENCIDO, true, null, null, null, envio);
        }
        long dias = ChronoUnit.DAYS.between(hoje, vencimento);
        String situacao = dias < 0 ? AtestadoDtos.VENCIDO : dias <= DIAS_AVISO ? AtestadoDtos.VENCENDO : AtestadoDtos.OK;
        String base = s.getAtestadoData() != null ? "ATESTADO" : "CADASTRO";
        return new Status(true, situacao, dias < 0 || s.isBloqueioAtestado(), vencimento, dias, base, envio);
    }

    /** Em análise, ou recusado e ainda não substituído; aprovado não aparece mais. */
    private Envio envioRelevante(UUID studentId) {
        return envios.findFirstByStudentIdOrderByEnviadoEmDesc(studentId)
                .filter(e -> !AtestadoEnvio.APROVADO.equals(e.getStatus()))
                .map(Envio::from)
                .orElse(null);
    }

    @Transactional
    public Envio enviar(UUID userId, EnvioRequest req, MultipartFile arquivo) {
        Student s = students.findByUserId(userId)
                .orElseThrow(() -> new NotFoundException("Nenhum aluno vinculado a esta conta."));
        if (!s.sujeitoAoAtestado()) {
            throw new BusinessException("O envio de atestado não se aplica ao seu perfil.");
        }
        if (arquivo == null || arquivo.isEmpty()) {
            throw new BusinessException("Anexe o atestado médico em PDF.");
        }
        if (!"application/pdf".equalsIgnoreCase(arquivo.getContentType())) {
            throw new BusinessException("O atestado médico precisa ser um arquivo PDF.");
        }
        LocalDate hoje = hoje();
        if (req.emissaoData().isAfter(hoje)) {
            throw new BusinessException("A data de emissão não pode ser no futuro.");
        }
        if (req.emissaoData().plusYears(1).isBefore(hoje)) {
            throw new BusinessException("Este atestado tem mais de 1 ano e já está vencido. Envie um atestado recente.");
        }
        if (envios.existsByStudentIdAndStatus(s.getId(), AtestadoEnvio.PENDENTE)) {
            throw new ConflictException("Você já tem um atestado em análise. Aguarde a validação da academia.");
        }
        Media media = storage.save(arquivo, Media.TIPO_ATESTADO_MEDICO);
        AtestadoEnvio e = new AtestadoEnvio();
        e.setStudent(s);
        e.setArquivoId(media.getId());
        e.setEmissaoData(req.emissaoData());
        e.setMedicoNome(req.medicoNome().trim());
        e.setMedicoCrm(req.medicoCrm().trim());
        e.setMedicoCrmUf(req.medicoCrmUf().trim().toUpperCase());
        return Envio.from(envios.save(e));
    }

    // ---------- admin: fila de validação ----------

    @Transactional(readOnly = true)
    public List<Pendente> pendentes() {
        LocalDate hoje = hoje();
        return envios.findByStatusOrderByEnviadoEmAsc(AtestadoEnvio.PENDENTE).stream().map(e -> {
            Student s = e.getStudent();
            LocalDate venc = s.vencimentoAtestado();
            Long dias = venc == null ? null : ChronoUnit.DAYS.between(hoje, venc);
            return new Pendente(e.getId(), s.getId(), s.getFullName(), Cpf.format(s.getCpf()), s.getEmail(),
                    s.getPhone(), s.getDepartment() != null ? s.getDepartment().getName() : null,
                    e.getEnviadoEm(), e.getEmissaoData(), e.getMedicoNome(), e.getMedicoCrm(), e.getMedicoCrmUf(),
                    e.getArquivoId(), venc, dias, (dias != null && dias < 0) || s.isBloqueioAtestado());
        }).toList();
    }

    /** Aprova: a data de emissão vira a nova base do vencimento e o bloqueio
     *  automático por atestado (se houver) é desfeito na hora. */
    @Transactional
    public Envio aprovar(UUID envioId, UUID adminId) {
        AtestadoEnvio e = pendente(envioId);
        Student s = e.getStudent();
        s.setAtestadoData(e.getEmissaoData());
        s.setAtestadoEmissaoData(e.getEmissaoData());
        s.setAtestadoArquivoId(e.getArquivoId());
        s.setMedicoNome(e.getMedicoNome());
        s.setMedicoCrm(e.getMedicoCrm());
        s.setMedicoCrmUf(e.getMedicoCrmUf());
        if (s.isBloqueioAtestado() && s.atestadoValido(hoje())) {
            desbloquear(s);
        }
        students.save(s);
        e.setStatus(AtestadoEnvio.APROVADO);
        e.setMotivoRecusa(null);
        e.setAnalisadoEm(OffsetDateTime.now());
        e.setAnalisadoPor(adminId);
        return Envio.from(envios.save(e));
    }

    @Transactional
    public Envio recusar(UUID envioId, String motivo, UUID adminId) {
        AtestadoEnvio e = pendente(envioId);
        e.setStatus(AtestadoEnvio.RECUSADO);
        e.setMotivoRecusa(motivo.trim());
        e.setAnalisadoEm(OffsetDateTime.now());
        e.setAnalisadoPor(adminId);
        return Envio.from(envios.save(e));
    }

    private AtestadoEnvio pendente(UUID envioId) {
        AtestadoEnvio e = envios.findById(envioId)
                .orElseThrow(() -> new NotFoundException("Envio de atestado não encontrado."));
        if (!AtestadoEnvio.PENDENTE.equals(e.getStatus())) {
            throw new BusinessException("Este atestado já foi analisado.");
        }
        return e;
    }

    // ---------- admin: painel ----------

    public static final String LISTA_VENCENDO = "vencendo";
    public static final String LISTA_BLOQUEADOS = "bloqueados";

    @Transactional(readOnly = true)
    public List<AlunoAtestado> alunos(String lista) {
        if (!LISTA_VENCENDO.equals(lista) && !LISTA_BLOQUEADOS.equals(lista)) {
            throw new BusinessException("Lista inválida — use vencendo ou bloqueados.");
        }
        LocalDate hoje = hoje();
        Set<UUID> emAnalise = envios.findByStatusOrderByEnviadoEmAsc(AtestadoEnvio.PENDENTE).stream()
                .map(e -> e.getStudent().getId()).collect(Collectors.toSet());
        return civisAprovados().stream()
                .filter(s -> s.vencimentoAtestado() != null || LISTA_BLOQUEADOS.equals(lista))
                .map(s -> linha(s, hoje, emAnalise.contains(s.getId())))
                .filter(l -> LISTA_VENCENDO.equals(lista)
                        ? !l.bloqueado() && l.diasRestantes() >= 0 && l.diasRestantes() <= DIAS_AVISO
                        : l.bloqueado())
                .sorted(Comparator.comparingLong(AlunoAtestado::diasRestantes))
                .toList();
    }

    @Transactional(readOnly = true)
    public Resumo resumo() {
        LocalDate hoje = hoje();
        long vencendo = 0, bloqueados = 0;
        for (Student s : civisAprovados()) {
            AlunoAtestado l = linha(s, hoje, false);
            if (l.bloqueado()) bloqueados++;
            else if (l.diasRestantes() >= 0 && l.diasRestantes() <= DIAS_AVISO) vencendo++;
        }
        return new Resumo(vencendo, bloqueados, envios.countByStatus(AtestadoEnvio.PENDENTE));
    }

    private AlunoAtestado linha(Student s, LocalDate hoje, boolean emAnalise) {
        LocalDate venc = s.vencimentoAtestado();
        long dias = venc == null ? -1 : ChronoUnit.DAYS.between(hoje, venc);
        return new AlunoAtestado(s.getId(), s.getFullName(), Cpf.mask(s.getCpf()),
                s.getDepartment() != null ? s.getDepartment().getName() : null, s.getPhone(), venc, dias,
                s.getAtestadoData() != null ? "ATESTADO" : "CADASTRO", dias < 0 || s.isBloqueioAtestado(), emAnalise);
    }

    private List<Student> civisAprovados() {
        return students.findByDeletedAtIsNullAndStatusCadastroAndStudentType(Student.STATUS_APROVADO, Student.TIPO_CIVIL);
    }

    // ---------- bloqueio automático ----------

    /** Diário às 02:00: bloqueia o civil cujo atestado venceu (e cancela os
     *  agendamentos dele de hoje em diante, o que também revoga a catraca), e
     *  desfaz o bloqueio automático de quem voltou a ter atestado válido ou
     *  deixou de estar sujeito à regra. Bloqueio manual do admin não é tocado. */
    @Scheduled(cron = "0 0 2 * * *", zone = "America/Sao_Paulo")
    public void rotinaDiaria() {
        ResultadoBloqueio r = aplicarBloqueios();
        if (r.bloqueados() + r.desbloqueados() > 0) {
            log.info("Atestados: {} bloqueado(s), {} desbloqueado(s), {} agendamento(s) cancelado(s).",
                    r.bloqueados(), r.desbloqueados(), r.agendamentosCancelados());
        }
    }

    @Transactional
    public ResultadoBloqueio aplicarBloqueios() {
        LocalDate hoje = hoje();
        int bloqueados = 0, desbloqueados = 0, cancelados = 0;
        for (Student s : students.findAll()) {
            if (s.getDeletedAt() != null || !Student.STATUS_APROVADO.equals(s.getStatusCadastro())) continue;
            boolean sujeito = s.sujeitoAoAtestado();
            boolean vencido = sujeito && s.vencimentoAtestado() != null && !s.atestadoValido(hoje);
            if (vencido && Student.SITUACAO_ATIVO.equals(s.getSituacao())) {
                s.setSituacao(Student.SITUACAO_BLOQUEADO);
                s.setBloqueioAtestado(true);
                students.save(s);
                bloqueados++;
                for (Appointment a : appointments.findAtivosDoAlunoAPartirDe(s.getId(), hoje)) {
                    scheduling.cancel(a.getId(), null, true);
                    cancelados++;
                }
            } else if (s.isBloqueioAtestado() && (!sujeito || s.atestadoValido(hoje))) {
                desbloquear(s);
                students.save(s);
                desbloqueados++;
            }
        }
        return new ResultadoBloqueio(bloqueados, desbloqueados, cancelados);
    }

    private static void desbloquear(Student s) {
        s.setBloqueioAtestado(false);
        if (Student.SITUACAO_BLOQUEADO.equals(s.getSituacao())) {
            s.setSituacao(Student.SITUACAO_ATIVO);
        }
    }
}
