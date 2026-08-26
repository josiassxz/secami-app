package br.gov.goias.secami.auth;

import br.gov.goias.secami.auth.web.dto.LoginRequest;
import br.gov.goias.secami.auth.web.dto.TokenResponse;
import br.gov.goias.secami.common.error.DomainExceptions.BusinessException;
import br.gov.goias.secami.identity.AppUser;
import br.gov.goias.secami.identity.AppUserRepository;
import br.gov.goias.secami.identity.Roles;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * Orquestra o login: valida credencial pelo {@link AuthProvider} ativo,
 * provisiona/atualiza o {@code app_user} (JIT) e emite os tokens. SPEC §12.2.
 */
@Service
public class AuthService {

    private final AuthProvider authProvider;
    private final AppUserRepository users;
    private final JwtService jwt;

    public AuthService(AuthProvider authProvider, AppUserRepository users, JwtService jwt) {
        this.authProvider = authProvider;
        this.users = users;
        this.jwt = jwt;
    }

    @Transactional
    public TokenResponse login(LoginRequest req) {
        AuthenticatedUser authed = authProvider
                .authenticate(req.username().trim(), req.password())
                .orElseThrow(() -> new BusinessException("Usuário ou senha inválidos."));

        AppUser user = provision(authed);
        if (!user.isAtivo()) {
            throw new BusinessException("Usuário inativo.");
        }
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
                .filter(AppUser::isAtivo)
                .orElseThrow(() -> new BusinessException("Usuário inválido."));
        return issueTokens(user);
    }

    /** Provisionamento just-in-time por objectGUID (AD) ou samAccountName. */
    private AppUser provision(AuthenticatedUser authed) {
        AppUser user = null;
        if (authed.ldapGuid() != null) {
            user = users.findByLdapGuid(authed.ldapGuid()).orElse(null);
        }
        if (user == null && authed.samAccountName() != null) {
            user = users.findBySamAccountNameIgnoreCase(authed.samAccountName()).orElse(null);
        }
        boolean isNew = user == null;
        if (isNew) {
            user = new AppUser();
            user.getRoles().add(Roles.ALUNO); // papel padrão no primeiro acesso (SPEC §12.3)
        }
        user.setLdapGuid(authed.ldapGuid());
        user.setSamAccountName(authed.samAccountName());
        user.setEmail(authed.email());
        user.setNome(authed.nome());
        user.setTipoIdentidade(authed.tipoIdentidade());
        // Não sobrescreve password_hash (usado só por identidade local/dev).
        return users.save(user);
    }

    private TokenResponse issueTokens(AppUser user) {
        List<String> roles = new ArrayList<>(user.getRoles());
        String access = jwt.generateAccessToken(user.getId(), roles);
        String refresh = jwt.generateRefreshToken(user.getId());
        return new TokenResponse(access, refresh, "Bearer", jwt.accessTokenSeconds(), roles);
    }
}
