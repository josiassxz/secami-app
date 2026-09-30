package br.gov.goias.secami.academy.student;

import br.gov.goias.secami.academy.department.Department;
import br.gov.goias.secami.academy.department.DepartmentRepository;
import br.gov.goias.secami.academy.student.StudentDtos.MeUpdateRequest;
import br.gov.goias.secami.academy.student.StudentDtos.UpsertRequest;
import br.gov.goias.secami.accelero.AcceleroSyncService;
import br.gov.goias.secami.common.Cpf;
import br.gov.goias.secami.common.error.DomainExceptions.ConflictException;
import br.gov.goias.secami.common.error.DomainExceptions.NotFoundException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.UUID;

@Service
public class StudentService {

    private final StudentRepository students;
    private final DepartmentRepository departments;
    private final AcceleroSyncService acceleroSync;
    private final StudentPerfilService perfis;

    public StudentService(StudentRepository students, DepartmentRepository departments,
                           AcceleroSyncService acceleroSync, StudentPerfilService perfis) {
        this.students = students;
        this.departments = departments;
        this.acceleroSync = acceleroSync;
        this.perfis = perfis;
    }

    /**
     * @param perfil filtro opcional: {@code aluno} (só Civil/Militar — é o que o
     *               instrutor vê pra prescrever ficha), {@code instrutor} ou
     *               nulo/vazio (todos os cadastros aprovados)
     */
    @Transactional(readOnly = true)
    public Page<Student> search(String q, String perfil, Pageable pageable) {
        String termo = q == null ? "" : q.trim();
        String filtro = perfil == null ? "" : perfil.trim().toLowerCase();
        if (!filtro.isEmpty() && !filtro.equals("aluno") && !filtro.equals("instrutor")) {
            throw new br.gov.goias.secami.common.error.DomainExceptions.BusinessException(
                    "Perfil inválido — use aluno ou instrutor.");
        }
        return students.buscar(termo, Student.STATUS_APROVADO, filtro, pageable);
    }

    @Transactional(readOnly = true)
    public Student get(UUID id) {
        return students.findByIdAndDeletedAtIsNull(id)
                .orElseThrow(() -> new NotFoundException("Aluno não encontrado."));
    }

    @Transactional(readOnly = true)
    public Student requireByUser(UUID userId) {
        return students.findByUserId(userId)
                .orElseThrow(() -> new NotFoundException("Nenhum aluno vinculado a esta conta."));
    }

    @Transactional
    public Student create(UpsertRequest req) {
        Student s = new Student();
        applyStaff(s, req, true);
        return students.save(s);
    }

    @Transactional
    public Student update(UUID id, UpsertRequest req) {
        Student s = get(id);
        boolean eraInstrutor = s.isInstrutor();
        applyStaff(s, req, false);
        Student salvo = students.save(s);
        // Só mexe nos papéis do login quando o perfil muda de fato (aluno ↔
        // instrutor) — editar outros campos nunca altera papel de ninguém.
        if (eraInstrutor != salvo.isInstrutor()) {
            perfis.sincronizarPapeis(salvo);
        }
        return salvo;
    }

    @Transactional
    public Student updateOwnProfile(UUID userId, MeUpdateRequest req) {
        Student s = requireByUser(userId);
        if (req.phone() != null) s.setPhone(req.phone());
        if (req.weightKg() != null) s.setWeightKg(req.weightKg());
        if (req.heightCm() != null) s.setHeightCm(req.heightCm());
        if (req.goal() != null) s.setGoal(req.goal());
        if (req.photoId() != null) s.setPhotoId(req.photoId());
        return students.save(s);
    }

    @Transactional
    public Student updateSituacao(UUID id, String novaSituacao) {
        if (!java.util.List.of(Student.SITUACAO_ATIVO, Student.SITUACAO_INATIVO, Student.SITUACAO_BLOQUEADO)
                .contains(novaSituacao)) {
            throw new br.gov.goias.secami.common.error.DomainExceptions.BusinessException("Situação inválida.");
        }
        Student s = get(id);
        s.setSituacao(novaSituacao);
        return students.save(s);
    }

    @Transactional
    public void delete(UUID id) {
        Student s = get(id);
        s.setDeletedAt(OffsetDateTime.now());
        s.setActive(false);
        students.save(s);
        // Tira o acesso físico à academia — best-effort, nunca impede a exclusão.
        acceleroSync.aoExcluirAluno(s);
    }

    private void applyStaff(Student s, UpsertRequest req, boolean isNew) {
        s.setFullName(req.fullName().trim());

        String cpf = Cpf.normalize(req.cpf());
        if (cpf != null) {
            students.findByCpf(cpf)
                    .filter(other -> !other.getId().equals(s.getId()))
                    .ifPresent(other -> { throw new ConflictException("Já existe aluno com este CPF."); });
        }
        s.setCpf(cpf);

        s.setMatricula(req.matricula());
        if (req.studentType() != null) {
            if (!Student.TIPOS.contains(req.studentType())) {
                throw new br.gov.goias.secami.common.error.DomainExceptions.BusinessException(
                        "Tipo inválido — use Civil, Militar ou Instrutor.");
            }
            s.setStudentType(req.studentType());
        }
        s.setPhone(req.phone());
        s.setEmail(req.email());
        s.setBirthDate(req.birthDate());
        s.setWeightKg(req.weightKg());
        s.setHeightCm(req.heightCm());
        s.setGoal(req.goal());
        s.setPhotoId(req.photoId());
        s.setAtestadoNumero(req.atestadoNumero());
        s.setAtestadoData(req.atestadoData());
        if (req.situacao() != null) s.setSituacao(req.situacao());
        else if (req.active() != null) s.setActive(req.active());

        if (req.departmentId() != null) {
            Department d = departments.findById(req.departmentId())
                    .orElseThrow(() -> new NotFoundException("Secretaria não encontrada."));
            s.setDepartment(d);
        } else {
            s.setDepartment(null);
        }
    }
}
