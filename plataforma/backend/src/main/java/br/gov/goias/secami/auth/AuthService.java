package br.gov.goias.secami.auth;

import br.gov.goias.secami.academy.student.Student;
import br.gov.goias.secami.academy.student.StudentRepository;
import br.gov.goias.secami.auth.web.dto.LoginRequest;
import br.gov.goias.secami.auth.web.dto.TokenResponse;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Orquestra o login: tenta os {@link AuthProvider}s em ordem (senha local,
 * depois conta do governo via LDAP, se ligado) e emite os tokens. Sem provisionamento just-in-time — o {@code app_user} nasce no
 * cadastro público (aluno) ou é criado pelo admin (staff), nunca no login.
 */
@Service
public class AuthService {

    private final List<AuthProvider> authProviders;
    private final AppUserRepository users;
    private final StudentRepository students;
    private final JwtService jwt;

    public AuthService(List<AuthProvider> authProviders, AppUserRepository users,
                        StudentRepository students, JwtService jwt) {
        this.authProviders = authProviders;
        this.users = users;
        this.students = students;
        this.jwt = jwt;
    }

    @Transactional
    public TokenResponse login(LoginRequest req) {
        String identificador = req.email().trim();
        UUID userId = authProviders.stream()
                .map(p -> p.authenticate(identificador, req.password()))
                .flatMap(Optional::stream)
                .findFirst()
                .orElseThrow(() -> new BusinessException("E-mail/usuário ou senha inválidos."));
        AppUser user = users.findById(userId)
                .orElseThrow(() -> new BusinessException("E-mail/usuário ou senha inválidos."));
        checkPodeLogar(user);
        return issueTokens(user);
    }

    @Transactional
    public TokenResponse refresh(String refreshToken) {
        UUID userId;
        try {
            Jws<Claims> jws = jwt.parse(refreshToken);
            Claims claims = jws.getPayload();
            if (!JwtService.TYPE_REFRESH.equals(claims.get("type", String.class))) {
                throw new BusinessException("Token de refresh inválido.");
            }
            userId = UUID.fromString(claims.getSubject());
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            throw new BusinessException("Token de refresh inválido ou expirado.");
        }
        AppUser user = users.findById(userId)
                .orElseThrow(() -> new BusinessException("Usuário inválido."));
        checkPodeLogar(user);
        return issueTokens(user);
    }

    /** Mensagem específica por motivo de bloqueio, em vez de "usuário inativo" genérico. */
    private void checkPodeLogar(AppUser user) {
        if (user.isAtivo()) {
            return;
        }
        Student student = students.findByUserId(user.getId()).orElse(null);
        if (student != null && Student.STATUS_PENDENTE.equals(student.getStatusCadastro())) {
            throw new BusinessException(
                    "Seu cadastro está em análise. Você receberá um aviso assim que for aprovado.");
        }
        if (student != null && Student.STATUS_REJEITADO.equals(student.getStatusCadastro())) {
            String motivo = student.getMotivoRejeicao();
            throw new BusinessException(motivo != null && !motivo.isBlank()
                    ? "Seu cadastro foi recusado: " + motivo
                    : "Seu cadastro foi recusado. Procure a administração da academia.");
        }
        throw new BusinessException("Usuário inativo. Procure a administração.");
    }

    private TokenResponse issueTokens(AppUser user) {
        List<String> roles = new ArrayList<>(user.getRoles());
        String access = jwt.generateAccessToken(user.getId(), roles);
        String refresh = jwt.generateRefreshToken(user.getId());
        return new TokenResponse(access, refresh, "Bearer", jwt.accessTokenSeconds(), roles);
    }
}
