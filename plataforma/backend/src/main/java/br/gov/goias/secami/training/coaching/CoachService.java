package br.gov.goias.secami.training.coaching;

import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.common.error.DomainExceptions.ConflictException;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import br.gov.goias.secami.training.coaching.CoachDtos.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

/** Coaching: convites e vínculos professor↔aluno. SPEC §9.3 / §11.2. */
@Service
public class CoachService {

    private static final String ALFABETO = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private static final int CODIGO_LEN = 6;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final VinculoRepository vinculos;
    private final ConviteRepository convites;
    private final AppUserRepository users;

    public CoachService(VinculoRepository vinculos, ConviteRepository convites, AppUserRepository users) {
        this.vinculos = vinculos;
        this.convites = convites;
        this.users = users;
    }

    @Transactional
    public Convite criarConvite(UUID professorId, String tipo, UUID orgId, Integer usosMax, Integer validadeDias) {
        Convite c = new Convite();
        c.setCodigo(gerarCodigoUnico());
        c.setTipo(tipo != null ? tipo : "professor_aluno");
        c.setCriadoPor(professorId);
        c.setOrgId(orgId);
        c.setUsosMax(usosMax != null && usosMax > 0 ? usosMax : 1);
        c.setExpiraEm(OffsetDateTime.now().plusDays(validadeDias != null && validadeDias > 0 ? validadeDias : 7));
        return convites.save(c);
    }

    @Transactional
    public void resgatar(String codigo, UUID alunoId) {
        Convite c = convites.findByCodigo(codigo.trim().toUpperCase())
                .orElseThrow(() -> new BusinessException("Código de convite inválido."));
        if (!c.valido(OffsetDateTime.now())) {
            throw new BusinessException("Convite expirado ou já utilizado.");
        }
        if (!"professor_aluno".equals(c.getTipo())) {
            throw new BusinessException("Tipo de convite não suportado neste fluxo.");
        }
        UUID professorId = c.getCriadoPor();
        if (professorId.equals(alunoId)) {
            throw new BusinessException("Você não pode se vincular a si mesmo.");
        }
        if (vinculos.existsByProfessorIdAndAlunoIdAndDeletedAtIsNull(professorId, alunoId)) {
            throw new ConflictException("Vínculo já existente com este treinador.");
        }
        Vinculo v = new Vinculo();
        v.setProfessorId(professorId);
        v.setAlunoId(alunoId);
        v.setStatus("ativo");
        v.setAceitoEm(OffsetDateTime.now());
        v.setOrgId(c.getOrgId());
        vinculos.save(v);

        // Garante que o aluno tenha o papel 'aluno' e o criador tenha 'professor'.
        addRole(alunoId, Roles.ALUNO);
        addRole(professorId, Roles.PROFESSOR);

        c.setUsos(c.getUsos() + 1);
        convites.save(c);
    }

    @Transactional(readOnly = true)
    public List<VinculoAlunoResponse> meusAlunos(UUID professorId) {
        return vinculos.findByProfessorIdAndStatusAndDeletedAtIsNull(professorId, "ativo").stream()
                .map(v -> new VinculoAlunoResponse(v.getId(), v.getStatus(), v.getAceitoEm(),
                        pessoa(v.getAlunoId())))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<VinculoTreinadorResponse> meusTreinadores(UUID alunoId) {
        return vinculos.findByAlunoIdAndStatusAndDeletedAtIsNull(alunoId, "ativo").stream()
                .map(v -> new VinculoTreinadorResponse(v.getId(), v.getStatus(), pessoa(v.getProfessorId())))
                .toList();
    }

    private PessoaResumo pessoa(UUID userId) {
        return users.findById(userId).map(PessoaResumo::from)
                .orElse(new PessoaResumo(userId, "(desconhecido)", null));
    }

    private void addRole(UUID userId, String role) {
        users.findById(userId).ifPresent(u -> {
            if (u.getRoles().add(role)) {
                users.save(u);
            }
        });
    }

    private String gerarCodigoUnico() {
        for (int tentativa = 0; tentativa < 10; tentativa++) {
            StringBuilder sb = new StringBuilder(CODIGO_LEN);
            for (int i = 0; i < CODIGO_LEN; i++) {
                sb.append(ALFABETO.charAt(RANDOM.nextInt(ALFABETO.length())));
            }
            String codigo = sb.toString();
            if (convites.findByCodigo(codigo).isEmpty()) {
                return codigo;
            }
        }
        throw new BusinessException("Não foi possível gerar um código de convite. Tente novamente.");
    }
}
