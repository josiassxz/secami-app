package br.gov.goias.secami.registration;

import br.gov.goias.secami.academy.department.Department;
import br.gov.goias.secami.academy.department.DepartmentRepository;
import br.gov.goias.secami.academy.media.Media;
import br.gov.goias.secami.academy.media.MediaStorageService;
import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.ConflictException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import br.gov.goias.secami.registration.RegistrationDtos.CadastroRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Cadastro público de aluno civil/militar (formulário "ACADEMIA ESPAÇO
 * SAÚDE" — PAR-Q + atestado médico) — fica pendente de aprovação do
 * admin/gerente antes de liberar o login.
 */
@Service
public class RegistrationService {

    /** As 10 perguntas do PAR-Q — todas obrigatórias, todas precisam de resposta. */
    static final Set<String> PAR_Q_PERGUNTAS = Set.of(
            "problema_coracao", "dor_peito_atividade", "dor_peito_mes",
            "desequilibrio_tontura", "problema_osseo_articular", "tratamento_pressao_coracao",
            "outra_razao_nao_praticar", "tratamento_continuo", "cirurgia_compromete_atividade",
            "outra_razao_compromete_saude");

    private final StudentRepository students;
    private final AppUserRepository users;
    private final DepartmentRepository departments;
    private final MediaStorageService storage;
    private final PasswordEncoder encoder;

    public RegistrationService(StudentRepository students, AppUserRepository users,
                                DepartmentRepository departments, MediaStorageService storage,
                                PasswordEncoder encoder) {
        this.students = students;
        this.users = users;
        this.departments = departments;
        this.storage = storage;
        this.encoder = encoder;
    }

    @Transactional
    public Student cadastrar(CadastroRequest req, MultipartFile atestado) {
        if (!Set.of("Civil", "Militar").contains(req.studentType())) {
            throw new BusinessException("Categoria inválida — use Civil ou Militar.");
        }
        if (!req.parQ().keySet().containsAll(PAR_Q_PERGUNTAS)) {
            throw new BusinessException("Responda todas as perguntas do questionário PAR-Q.");
        }
        if (atestado == null || atestado.isEmpty()) {
            throw new BusinessException("O atestado médico em PDF é obrigatório.");
        }
        if (!"application/pdf".equalsIgnoreCase(atestado.getContentType())) {
            throw new BusinessException("O atestado médico precisa ser um arquivo PDF.");
        }

        String email = req.email().trim().toLowerCase();
        if (users.findByEmailIgnoreCase(email).isPresent()) {
            throw new ConflictException("Já existe um cadastro com este e-mail.");
        }
        String cpf = Cpf.normalize(req.cpf());
        if (cpf != null && students.findByCpf(cpf).isPresent()) {
            throw new ConflictException("Já existe um cadastro com este CPF.");
        }
        Department department = departments.findById(req.departmentId())
                .orElseThrow(() -> new NotFoundException("Secretaria/órgão não encontrado."));

        // Fica inativo até o admin aprovar (AuthService.checkPodeLogar dá a
        // mensagem de "cadastro em análise" quando o login é tentado).
        AppUser user = new AppUser();
        user.setNome(req.fullName().trim());
        user.setEmail(email);
        user.setTipoIdentidade("local");
        user.setAtivo(false);
        user.setPasswordHash(encoder.encode(req.password()));
        user.getRoles().add(Roles.ALUNO);
        user = users.save(user);

        Media atestadoMedia = storage.save(atestado, Media.TIPO_ATESTADO_MEDICO);

        Student s = new Student();
        s.setUserId(user.getId());
        s.setFullName(req.fullName().trim());
        s.setCpf(cpf);
        s.setStudentType(req.studentType());
        s.setDepartment(department);
        s.setPhone(req.whatsapp());
        s.setEmail(email);
        s.setBirthDate(req.birthDate());
        s.setWeightKg(req.weightKg());
        s.setHeightCm(req.heightCm());
        s.setObjetivos(req.objetivos() != null ? req.objetivos() : List.of());
        s.setParQ(req.parQ());
        OffsetDateTime agora = OffsetDateTime.now();
        s.setTermoResponsabilidadeAceitoEm(agora);
        s.setTermoCienciaAceitoEm(agora);
        s.setMedicoNome(req.medicoNome().trim());
        s.setMedicoCrm(req.medicoCrm().trim());
        s.setMedicoCrmUf(req.medicoCrmUf());
        s.setAtestadoEmissaoData(req.atestadoEmissaoData());
        s.setAtestadoArquivoId(atestadoMedia.getId());
        // Espelha o atestado no campo já usado pelas regras de agendamento
        // (SchedulingService.atestadoValido) — sem isso um Civil aprovado
        // ficaria bloqueado por "atestado ausente" mesmo tendo enviado um.
        s.setAtestadoData(req.atestadoEmissaoData());
        s.setStatusCadastro(Student.STATUS_PENDENTE);
        s.setActive(true);
        return students.save(s);
    }

    @Transactional(readOnly = true)
    public List<Student> listarPendentes() {
        return students.findByStatusCadastroAndDeletedAtIsNullOrderByCreatedAtAsc(Student.STATUS_PENDENTE);
    }

    @Transactional
    public Student aprovar(UUID studentId) {
        Student s = pendente(studentId);
        s.setStatusCadastro(Student.STATUS_APROVADO);
        s.setMotivoRejeicao(null);
        students.save(s);
        ativarUsuario(s.getUserId(), true);
        return s;
    }

    @Transactional
    public Student rejeitar(UUID studentId, String motivo) {
        Student s = pendente(studentId);
        s.setStatusCadastro(Student.STATUS_REJEITADO);
        s.setMotivoRejeicao(motivo);
        students.save(s);
        ativarUsuario(s.getUserId(), false);
        return s;
    }

    private Student pendente(UUID studentId) {
        Student s = students.findByIdAndDeletedAtIsNull(studentId)
                .orElseThrow(() -> new NotFoundException("Cadastro não encontrado."));
        if (!Student.STATUS_PENDENTE.equals(s.getStatusCadastro())) {
            throw new BusinessException("Este cadastro já foi analisado.");
        }
        return s;
    }

    private void ativarUsuario(UUID userId, boolean ativo) {
        if (userId == null) return;
        users.findById(userId).ifPresent(u -> {
            u.setAtivo(ativo);
            users.save(u);
        });
    }
}
